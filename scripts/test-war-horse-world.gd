# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-dark-horse-world.gd"

const OriginalHorse := preload("res://Presentation/SourceWarHorseVisual.gd")


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
	for body: int in OriginalHorse.FormsByBody:
		var serial := 0x7a00 + body * 8
		if body != OriginalHorse.EtherealBody and not await check_original_loose(world, at, serial, body, enhanced):
			return
		var item: int = OriginalHorse.FormsByBody[body][1]
		if item > 0 and not check_original_riders(world, at, serial, body, item, enhanced):
			return
	if not expect(Mounts.horse_body(0) == 0, "no riding graphic is assigned to Pack Horse"):
		return
	print("ORIGINAL WAR HORSE WORLD: ", checks, " checks, Enhanced ", enhanced)
	quit()


func check_original_loose(world: Node3D, at: Vector2i, serial: int, body: int, enhanced: bool) -> bool:
	var native := mobile_packet(at, serial, body, 0)
	native[13] = CorpseHue >> 8
	native[14] = CorpseHue & 0xff
	world.game._handle(native)
	var avatar: Node3D = world.avatars[serial]
	var actor: Node3D = avatar.horse_visual
	if not expect((actor is OriginalHorse) == enhanced and actor.native_body == body and actor.native_hue == CorpseHue,
			"the loose visual retains its identity and exact hue, body %d" % body):
		return false
	if not enhanced:
		return true
	var pack := body == OriginalHorse.PackBody
	if not expect(actor.skeleton.get_bone_count() == (38 if pack else 37)
			and not actor.harness.visible and not actor.reins.visible and not Mounts.mount_available(body, 0x3ea7),
			"the original loose rig shows no ridden fittings or mismatched item"):
		return false
	for movement: Array in [[false, 0., "Idle"], [true, 1.8, "Walk"], [true, 5.4, "Run"]]:
		avatar.animate(movement[0], 0., .15, movement[1])
		if not expect(actor.current_clip == movement[2] and actor.animator.has_animation(movement[2]),
				"normal movement selects the original rig's gait"):
			return false
	for sample: Array in [[3, "Eat"], [5, "Attack"], [7, "Hit"], [9, "Fidget"]]:
		world.game._handle(classic_packet(serial, sample[0]))
		if not expect(actor.current_clip == sample[1] and not actor.dead,
				"the decoded Classic group plays on the source rig"):
			return false
	if body == 117:
		world.game._handle(breath_packet(serial))
		if not expect(actor.current_clip == DarkHorse.Breath and absf(actor.action_remaining - 1.67) < .04,
				"native Holy Steed breath has a dedicated windup"):
			return false
		actor.animator.advance(.14)
		actor.animator.seek(1.3, true)
		var muzzle: Vector3 = actor.fire_breath_origin()
		var presenter := Effects.new()
		presenter.scene = world
		var actual := presenter._bolt_origin({"graphic": 0x36d4, "source": serial})
		presenter.free()
		if not expect(muzzle.distance_to(actual) < .001 and muzzle.distance_to(actor.global_position) > .9,
				"the stock effect is launched from the posed muzzle"):
			return false
	if pack:
		var mesh: MeshInstance3D = actor.model.find_children("*", "MeshInstance3D", true, false)[0]
		if not expect(mesh.mesh.get_surface_count() == 2
				and actor.skeleton.find_bone("equines_horse_pack") >= 0 and actor.pack_fitting == null,
				"original cargo is carried by its own joint and skin surface"):
			return false
	var has_fits := body in [OriginalHorse.BritannianBody, OriginalHorse.PackBody]
	if has_fits and not check_enhanced_routes(world, at, serial + 7, body):
		return false
	for variation: int in ([-1, 12, 0, 1] if has_fits else [-1, 12]):
		var dying := serial + {-1: 3, 12: 4, 0: 5, 1: 6}[variation] as int
		var fall_clip := "Death2" if variation == 1 else "Death"
		if not await verify_fall(world, at, dying, variation, fall_clip, body):
			return false
		if pack:
			var corpse := 0x4002f000 + dying
			var frozen: Node3D = world.world_items.nodes[corpse].get_node("CorpseVisual")
			if not expect(surfaces(frozen).values().any(func(parts: Array): return parts.size() == 2),
					"the dyed static native corpse keeps the original cargo"):
				return false
	return true


func check_enhanced_routes(world: Node3D, at: Vector2i, serial: int, body: int) -> bool:
	world.game._handle(mobile_packet(at, serial, body, 0))
	var avatar: Node3D = world.avatars[serial]
	var actor := avatar.horse_visual as OriginalHorse
	var pack := body == OriginalHorse.PackBody
	world.game._handle(mobile_packet(at, serial, body, 0x40))
	if not expect(actor.current_clip == ("Idle" if pack else "HorseAlert"),
			"the peaceful-to-combat transition uses the body-specific registered choice"):
		return false
	actor.action_remaining = 0.
	avatar.animate(false, 0., .15, 0.)
	if not expect(actor.current_clip == "HorseCombatIdle", "the original combat mode gets its own idle"):
		return false
	var requests := [[0, 0, "HorseRearStrike"], [2, 1, "HorseForelegGuard"], [4, 0, "HorseHeadRecoil"],
		[5, 0, "HorseHighFidget" if pack else "HorseQuietNod"], [5, 1, "HorseHighFidget"],
		[8, 0, "HorseAlert"], [11, 0, "HorseRearCast" if pack else "HorseRearStrike"]]
	requests.append([1, 0, "HorseForelegGuard"] if pack else [14, 0, "Idle"])
	for test: Array in requests:
		world.game._handle(action_packet(serial, test[0], test[1]))
		if not expect(actor.current_clip == test[2], "normal decoded Enhanced action uses the registered motion"):
			return false
	actor.action_remaining = 0.
	world.game._handle(mobile_packet(at, serial, body, 0))
	world.game._handle(action_packet(serial, 5, 1))
	return expect(actor.current_clip == "HorseQuietNod", "peaceful mode uses the subtle head gesture")


func check_original_riders(world: Node3D, at: Vector2i, serial: int, body: int, item: int, enhanced: bool) -> bool:
	for rider_body: int in [400, 401]:
		var rider_serial := serial + rider_body - 399
		var spectral := item == OriginalHorse.EtherealItem
		var hue := 0x4001 if spectral else CorpseHue
		world.game._handle(mobile_packet(at, rider_serial, rider_body, 0))
		world.game._handle(wear_packet(rider_serial, item, hue))
		var actor: Node3D = world.avatars[rider_serial].horse_visual
		if not expect((actor is OriginalHorse) == enhanced and actor.native_body == body
				and actor.native_hue == hue and actor.native_mount_item == item,
				"native worn item selects the correct mount and hue"):
			return false
		if not enhanced:
			continue
		var mesh: MeshInstance3D = actor.model.find_children("*", "MeshInstance3D", true, false)[0]
		var coat := mesh.get_surface_override_material(0) as ShaderMaterial
		if not expect(actor.harness.visible and actor.reins.visible and actor.seat().is_finite()
				and coat.shader == (OriginalHorse.SpectralCoat if spectral else OriginalHorse.OpaqueCoat)
				and coat.get_shader_parameter("use_hue") == not spectral,
				"mounted tack follows the rig with the correct opaque or spectral material"):
			return false
		if body in [119, 120, 121, OriginalHorse.EtherealBody] and not expect(
				coat.get_shader_parameter("albedo_texture") == OriginalHorse.war_atlases[body],
				"the shared rig uses this identity's verified original atlas"):
			return false
		if spectral and not expect(not Mounts.matches(actor, body, 0),
				"the spectral renderer cannot be reused for an ordinary loose horse"):
			return false
		world.game._handle(breath_packet(rider_serial))
		if not expect(not actor.dead and actor.current_clip != DarkHorse.Breath,
				"rider actions cannot trigger a loose steed's breath"):
			return false
	return true
