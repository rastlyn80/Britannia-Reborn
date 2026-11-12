# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const DarkHorse := preload("res://Presentation/SourceDarkHorseVisual.gd")
const Effects := preload("res://Presentation/SourceEnhancedFireBreathProjectilePresenter.gd")


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
	for body: int in DarkHorse.NativeItems:
		if not await check_dark_horse(world, at, body, enhanced):
			return
	print("DARK HORSE WORLD: ", checks, " checks across four native identities, Enhanced ", enhanced)
	quit()


func check_dark_horse(world: Node3D, at: Vector2i, body: int, enhanced: bool) -> bool:
	var serial := 0x6200 + body * 12
	var item: int = DarkHorse.NativeItems[body]
	var native := mobile_packet(at, serial, body, 0x40)
	native[13] = CorpseHue >> 8
	native[14] = CorpseHue & 0xff
	world.game._handle(native)
	var avatar: Node3D = world.avatars[serial]
	var loose: Node3D = avatar.horse_visual
	if not expect((loose is DarkHorse) == enhanced and loose.native_body == body and loose.native_hue == CorpseHue,
			"normal appearance selects the exact loose identity and raw server hue"):
		return false
	for rider_body: int in [400, 401]:
		var rider_serial := serial + rider_body - 399
		world.game._handle(mobile_packet(at, rider_serial, rider_body, 0))
		world.game._handle(wear_packet(rider_serial, item, CorpseHue))
		var rider: Node3D = world.avatars[rider_serial]
		var mount: Node3D = rider.horse_visual
		if not expect((mount is DarkHorse) == enhanced and mount.native_body == body
				and mount.native_mount_item == item and mount.native_hue == CorpseHue,
				"stock mount layer retains the exact item, hue and body"):
			return false
		if enhanced and not expect(mount.harness.visible and mount.reins.visible and mount.seat().is_finite(),
				"the fitted tack follows the original rig"):
			return false
		world.game._handle(breath_packet(rider_serial))
		if not expect(not mount.dead and mount.current_clip != DarkHorse.Breath,
				"a rider action cannot start a loose creature breath"):
			return false
	if not enhanced:
		return true
	if not expect(loose.skeleton.get_bone_count() == 37 and not loose.harness.visible and not loose.reins.visible,
			"loose original horse has no mounted tack"):
		return false
	if not expect(not Mounts.matches(loose, 178 if body == 116 else 116), "a distinct native body cannot reuse the wrong visual identity"):
		return false
	for sample: Array in [[5, "Attack"], [7, "Hit"], [9, "Fidget"]]:
		world.game._handle(classic_packet(serial, sample[0]))
		if not expect(loose.current_clip == sample[1] and not loose.dead, "Classic selections preserve the original motion keys"):
			return false
	world.game._handle(breath_packet(serial))
	if not expect(loose.current_clip == DarkHorse.Breath and not loose.dead
			and absf(loose.action_remaining - 1.67) < .04, "stock breath starts the dedicated windup"):
		return false
	loose.animator.advance(.13)
	loose.animator.seek(1.3, true)
	loose.skeleton.force_update_all_bone_transforms()
	var expected: Vector3 = loose.fire_breath_origin()
	var presenter := Effects.new()
	presenter.scene = world
	var actual := presenter._bolt_origin({"graphic": 0x36d4, "source": serial})
	presenter.free()
	if not expect(actual.distance_to(expected) < .001 and actual.distance_to(loose.global_position) > .9,
			"the real effect presenter launches stock 0x36D4 from the posed muzzle"):
		return false
	for sample: Array in [[-1, "Death"], [0, "Death"]]:
		serial += 3
		if not await verify_fall(world, at, serial, sample[0], sample[1], body):
			return false
	return true


func breath_packet(serial: int) -> PackedByteArray:
	var packet := classic_packet(serial, 12)
	packet[8] = 5
	packet[11] = 0
	return packet
