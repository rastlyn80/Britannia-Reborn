# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Breath := preload("res://Presentation/LavaSnakeFireBreath.gd")
const Effects := preload("res://Presentation/EffectPresenter.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Source := 0x4631
const Target := 0x4632


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
	var hues: Array = Breath.Hues + [0x480, 2001]
	for index in hues.size():
		var serial := Source + 10 + index
		var hue: int = hues[index]
		var mobile := mobile_packet(tile, serial, Breath.Body, 0)
		var wire_hue := Wire.uint_be(hue, 2)
		mobile[13] = wire_hue[0]
		mobile[14] = wire_hue[1]
		world.game._handle(mobile)
		var snake: Node3D = world.avatars[serial].horse_visual
		if not expect(snake != null and snake.native_hue == hue, "Body 52 native hue %x" % hue):
			return
		snake.set_process(false)
		snake.set_physics_process(false)
		snake.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		world.game._handle(gesture(serial, 12, 5))
		if hue not in Breath.Hues:
			if not expect(snake.dead and snake.current_clip == "Death" and Breath.origin(snake) == null,
					"Shared-body snake retains its collapse"):
				return
			continue
		if not expect(snake.current_clip == Breath.Clip and not snake.dead, "Lava Snake windup for hue %x" % hue):
			return
		snake.animator.advance(0.0)
		world.game._handle(gesture(serial, 5, 5))
		world.game._handle(action_packet(serial, 0, 1))
		snake.play_gait(true, 4.0)
		var rig: Skeleton3D = snake.skeleton
		var floor := snake.global_position
		var slope := Vector3(0.20, 1.0, -0.16).normalized()
		snake.terrain.plane = {"position": floor, "normal": slope}
		var clearance := INF
		for frame in 78:
			snake.animator.advance(1.0 / 60.0)
			snake._process(1.0 / 60.0)
			if frame % 6 == 5:
				clearance = minf(clearance, Ground.minimum_plane_gap(
					snake.terrain.skin, rig, rig.global_transform, floor, slope))
		if not expect(clearance >= 0.0029, "Fire-breath windup keeps the snake above the slope %.5f" % clearance):
			return
		var muzzle: Variant = Breath.origin(snake)
		var before: int = presenter.get_child_count()
		world.game._handle(projectile(tile, serial))
		var launch := presenter.get_child(before) as Node3D
		if not expect(muzzle is Vector3 and launch != null and launch.global_position.distance_to(muzzle) < 0.00001,
				"The bolt follows the animated head"):
			return
		world.game._handle(gesture(serial, 8, 5))
		if not expect(snake.dead and Breath.origin(snake) == null, "Native death interrupts breath"):
			return
		var corpse := 0x40000000 + serial
		world.game._handle(corpse_packet(tile, corpse, Breath.Body, hue))
		world.game._handle(death_packet(serial, corpse))
		world.creature_deaths.finish(serial)
		var frozen: Node3D = world.world_items.nodes[corpse].get_node_or_null("CorpseVisual")
		if not expect(frozen != null and frozen.get_meta("corpse_body") == Breath.Body
				and frozen.get_meta("native_hue") == hue
				and frozen.find_children("*", "Skeleton3D", true, false).is_empty(), "Native hue on static snake corpse"):
			return
	world.game.phase = "offline"
	print("LAVA SNAKE WORLD: ", checks, " packet and pose checks, Enhanced ", world.enhanced_creature_actions)
	quit()


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
