# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-dark-horse-world.gd"

const Skeletal := preload("res://Presentation/SourceSkeletalHorseVisual.gd")


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	if not await check_skeletal(world, at, enhanced):
		return
	print("SKELETAL MOUNT WORLD: ", checks, " checks, Enhanced ", enhanced)
	quit()


func check_skeletal(world: Node3D, at: Vector2i, enhanced: bool) -> bool:
	var serial := 0x7900
	var native := mobile_packet(at, serial, Skeletal.Body, 0x40)
	native[14] = 0x21
	world.game._handle(native)
	var loose: Node3D = world.avatars[serial].horse_visual
	if not expect((loose is Skeletal) == enhanced and loose.native_body == Skeletal.Body and loose.native_hue == 0x21,
			"the normal client keeps the skeletal body and Red Death tint"):
		return false
	for rider_body in [400, 401]:
		var rider_serial: int = serial + rider_body - 399
		world.game._handle(mobile_packet(at, rider_serial, rider_body, 0))
		world.game._handle(wear_packet(rider_serial, Skeletal.Item, CorpseHue))
		var mount: Node3D = world.avatars[rider_serial].horse_visual
		if not expect((mount is Skeletal) == enhanced and mount.native_body == Skeletal.Body
				and mount.native_hue == CorpseHue and mount.native_mount_item == Skeletal.Item,
				"the normal equipped route keeps native body, item and partial tint"):
			return false
		world.game._handle(breath_packet(rider_serial))
		if not expect(not mount.dead and mount.current_clip != DarkHorse.Breath, "a rider packet cannot start Chaos Breath"):
			return false
	if not enhanced:
		return true
	if not expect(loose.skeleton.get_bone_count() == 34 and not loose.harness.visible and not loose.reins.visible
			and not Mounts.mount_available(Skeletal.Body, 0x3ea7), "the loose model has the original rig and no mounted tack"):
		return false
	for sample: Array in [[3, "Eat"], [5, "Attack"], [6, "Attack2"], [7, "Hit"], [9, "Fidget"], [10, "Fidget2"]]:
		world.game._handle(classic_packet(serial, sample[0]))
		if not expect(loose.current_clip == sample[1] and not loose.dead, "the decoded Classic group selects its source clip"):
			return false
	world.game._handle(breath_packet(serial))
	if not expect(loose.current_clip == DarkHorse.Breath and absf(loose.action_remaining - 1.67) < .04,
			"the native Chaos Breath selector starts the authored clip"):
		return false
	loose.animator.advance(.13)
	loose.animator.seek(1.3, true)
	var muzzle: Vector3 = loose.fire_breath_origin()
	var presenter := Effects.new()
	presenter.scene = world
	var launch := presenter._bolt_origin({"graphic": 0x36d4, "source": serial})
	presenter.free()
	if not expect(launch.distance_to(muzzle) < .001 and launch.distance_to(loose.global_position) > 1.15,
			"the native projectile starts at the skeletal muzzle"):
		return false
	if not check_enhanced_modes(world, at, serial + 16):
		return false
	for packet_order in [-1, 0, 1, 12]:
		serial += 3
		var fall_clip := "Death2" if packet_order == 1 else "Death"
		if not await verify_fall(world, at, serial, packet_order, fall_clip, Skeletal.Body):
			return false
	return true


func check_enhanced_modes(world: Node3D, at: Vector2i, serial: int) -> bool:
	world.game._handle(mobile_packet(at, serial, Skeletal.Body, 0))
	var avatar: Node3D = world.avatars[serial]
	var actor := avatar.horse_visual as Skeletal
	for test: Array in [[false, 0., "Idle"], [true, 1.8, "Walk"], [true, 5.4, "Run"]]:
		avatar.animate(test[0], 0., .15, test[1])
		if not expect(actor.current_clip == test[2], "normal movement keeps the original gait"):
			return false
	world.game._handle(mobile_packet(at, serial, Skeletal.Body, 0x40))
	if not expect(actor.current_clip == "SkeletalAlert", "the decoded peaceful-to-combat transition selects group 28"):
		return false
	actor.action_remaining = 0.
	avatar.animate(false, 0., .15, 0.)
	if not expect(actor.current_clip == "SkeletalCombatIdle", "the combat state selects its own idle"):
		return false
	for test: Array in [[0, 0, "SkeletalRearStrike"], [2, 1, "SkeletalForelegGuard"], [4, 0, "Hit"],
			[5, 0, "SkeletalQuietNod"], [5, 1, "SkeletalHighFidget"], [8, 0, "SkeletalAlert"],
			[11, 2, "SkeletalRearCast"], [14, 0, "Idle"], [15, 0, "Idle"]]:
		world.game._handle(action_packet(serial, test[0], test[1]))
		if not expect(actor.current_clip == test[2], "normal decoded action selects its registered Enhanced group"):
			return false
	actor.action_remaining = 0.
	world.game._handle(mobile_packet(at, serial, Skeletal.Body, 0))
	world.game._handle(action_packet(serial, 5, 1))
	return expect(actor.current_clip == "SkeletalQuietNod", "peaceful fidget never selects the combat rear")
