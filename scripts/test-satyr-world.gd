# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Singer := 0x4511
const Other := 0x4512


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	world.game._handle(mobile_packet(at, Singer, 271, 0))
	var singer: Node3D = world.avatars[Singer].horse_visual
	world.game.phase = "world"
	for sound_id: int in [0x58d, 0x58c, 0x58a]:
		singer.action_remaining = 0.0
		singer.play_gait(false, 0.0)
		world.game._handle(sound_packet(sound_id, at + Vector2i(1, 0), 0))
		assert(singer.current_clip == "Idle")
		world.game._handle(sound_packet(sound_id, at, 0))
		assert(singer.current_clip == "SatyrLean")
	world.game._handle(mobile_packet(at, Other, 271, 0))
	singer.action_remaining = 0.0
	singer.play_gait(false, 0.0)
	world.game._handle(sound_packet(0x58d, at, 0))
	assert(singer.current_clip == "Idle" and world.avatars[Other].horse_visual.current_clip == "Idle")
	world.game.phase = "offline"
	print("SATYR WORLD: 8 decoded song checks, Enhanced ", "--enhanced-creature-actions" in OS.get_cmdline_user_args())
	quit()


func sound_packet(sound_id: int, at: Vector2i, z: int) -> PackedByteArray:
	var packet := PackedByteArray([0x54, 1])
	for field: int in [sound_id, 0, at.x, at.y, z]:
		packet.append_array(Wire.uint_be(field, 2))
	return packet
