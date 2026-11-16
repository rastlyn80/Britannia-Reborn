# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Effects := preload("res://Presentation/EffectPresenter.gd")
const Source := 0x4680
const Target := 0x4690


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	for child in world.get_children():
		if child.get_script() == preload("res://Network/MobileNames.gd"):
			child.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var tile := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	world.game._handle(mobile_packet(tile + Vector2i(3, 0), Target, 211, 0))
	world.game.phase = "world"
	var presenter: Node3D
	for child in world.get_children():
		if child is Effects:
			presenter = child
			break
	if not expect(presenter != null, "Real effect presenter"):
		return
	var cases: Array = [[206, 0x650, "lava_lizard/FireBreath"], [90, 0, "LavaSerpentFireBreath"]]
	for index in cases.size():
		var case: Array = cases[index]
		if not Registry.supports_body(case[0]):
			continue
		if not check_reptile(world, presenter, tile, Source + index, case[0], case[1], case[2]):
			return
	world.game.phase = "offline"
	print("LAVA REPTILE WORLD: ", checks, " packet and pose checks, Enhanced ", world.enhanced_creature_actions)
	quit()


func check_reptile(world: Node3D, presenter: Node3D, tile: Vector2i, serial: int, body: int, hue: int, clip: String) -> bool:
	var mobile := mobile_packet(tile, serial, body, 0)
	var wire_hue := Wire.uint_be(hue, 2)
	mobile[13] = wire_hue[0]
	mobile[14] = wire_hue[1]
	world.game._handle(mobile)
	var reptile: Node3D = world.avatars[serial].horse_visual
	if not expect(reptile != null and reptile.native_body == body and reptile.native_hue == hue, "Native reptile identity"):
		return false
	reptile.set_process(false)
	reptile.set_physics_process(false)
	reptile.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	world.game._handle(gesture(serial, 12, 5))
	if not expect(reptile.current_clip == clip and not reptile.dead and reptile.action_remaining > 1.30,
			"Fire-breath pose for body %d" % body):
		return false
	if not expect(reptile.get_meta("native_action") == world.game.last_mobile_actions[serial], "Original request remains observable"):
		return false
	reptile.animator.advance(0.0)
	world.game._handle(gesture(serial, 4, 5))
	world.game._handle(action_packet(serial, 0, 1))
	reptile.play_gait(true, 4.0)
	for frame in 78:
		reptile.animator.advance(1.0 / 60.0)
		reptile._process(1.0 / 60.0)
	var muzzle: Variant = reptile.fire_breath_origin()
	var before: int = presenter.get_child_count()
	world.game._handle(projectile(tile, serial))
	var launch := presenter.get_child(before) as Node3D
	if not expect(muzzle is Vector3 and launch != null and launch.global_position.distance_to(muzzle) < 0.00001,
			"Firebolt launches from head during overlapping attacks"):
		return false
	world.game._handle(gesture(serial, 2, 5))
	if not expect(reptile.dead and reptile.fire_breath_origin() == null, "Native fall interrupts fire breath"):
		return false
	var corpse := 0x40000000 + serial
	world.game._handle(corpse_packet(tile, corpse, body, hue))
	world.game._handle(death_packet(serial, corpse))
	world.creature_deaths.finish(serial)
	var frozen: Node3D = world.world_items.nodes[corpse].get_node_or_null("CorpseVisual")
	return expect(frozen != null and frozen.get_meta("corpse_body") == body
		and frozen.get_meta("native_hue") == hue
		and frozen.find_children("*", "Skeleton3D", true, false).is_empty(), "Static native corpse")


func gesture(serial: int, group: int, frames: int) -> PackedByteArray:
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(PackedByteArray([0, group, 0, frames, 0, 1, 0, 0, 0]))
	return packet


func projectile(tile: Vector2i, serial: int) -> PackedByteArray:
	var packet := PackedByteArray([0x70, 0])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(Wire.uint_be(Target, 4))
	packet.append_array(Wire.uint_be(0x36d4, 2))
	packet.append_array(Wire.uint_be(tile.x, 2))
	packet.append_array(Wire.uint_be(tile.y, 2))
	packet.append(0)
	packet.append_array(Wire.uint_be(tile.x + 3, 2))
	packet.append_array(Wire.uint_be(tile.y, 2))
	packet.append_array(PackedByteArray([0, 5, 0, 0, 0, 0, 0]))
	return packet
