# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Cases := {1: 9, 33: 9, 51: 9, 54: 9}


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var point := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	var serial := 0x5300
	for body: int in Cases:
		serial += 1
		world.game._handle(mobile_packet(point, serial, 400, 0))
		world.game._handle(mobile_packet(point, serial, body, 0))
		var visual: Node3D = world.avatars[serial].horse_visual
		if not expect(visual != null and visual.native_body == body, "Normal World shows the Polymorph body"):
			return
		world.game._handle(action(serial, 9, 7, 1))
		if not expect(visual.current_clip != "CreatureDaggerThrow", "An unrelated packet does not use the throw"):
			return
		if not witness_throw(world, serial, visual, 9, 7, "CreatureDaggerThrow"):
			return
		if body == 33:
			if not witness_throw(world, serial, visual, 11, 5, "CreatureBolaThrow"):
				return
			world.game._handle(action(serial, 11, 5, 1))
			if not expect(visual.get_meta("native_action", {}).get("delay") == 0,
					"Monster approach packet remains distinct from the bola toss"):
				return
		world.game._handle(mobile_packet(point, serial, 400, 0))
		if not expect(world.avatars[serial].human_visual != null, "The return packet restores the human model"):
			return
	print("PLAYER ITEM ACTION WORLD: ", checks, " checks, Enhanced ", world.enhanced_creature_actions)
	quit(0)


func witness_throw(world: Node, serial: int, visual: Node3D, group: int, frames: int, clip: String) -> bool:
	world.game._handle(action(serial, group, frames, 0))
	var native: Dictionary = visual.get_meta("native_action", {})
	if not expect(visual.current_clip == clip and not visual.dead and native.get("action") == group
			and native.get("frames") == frames and native.get("delay") == 0, "Original item packet plays " + clip + str([visual.native_body, visual.current_clip, visual.action_profile, visual.treatment, native, visual.get_meta("unsupported_action", {})])):
		return false
	var player: AnimationPlayer = visual.animator
	var rig: Skeleton3D = visual.skeleton
	var hand := rig.find_bone("bip01 r hand")
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var duration := player.current_animation_length
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var start := rig.get_bone_global_pose(hand).origin
	player.seek(.55 * duration, true)
	rig.force_update_all_bone_transforms()
	var distance := start.distance_to(rig.get_bone_global_pose(hand).origin)
	return expect(distance > .05, "The throwing hand moves visibly through release: %s %f" % [visual.native_body, distance])


func action(serial: int, group: int, frames: int, delay: int) -> PackedByteArray:
	var wire := PackedByteArray([0x6e])
	wire.append_array(Wire.uint_be(serial, 4))
	wire.append_array(PackedByteArray([0, group, 0, frames, 0, 1, 0, 0, delay]))
	return wire
