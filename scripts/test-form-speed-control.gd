# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

class ProbeSession extends "res://Network/GameSession.gd":
	var sent := PackedByteArray()
	func send(bytes: PackedByteArray) -> void:
		sent = bytes.duplicate()

func _initialize() -> void:
	create_timer(8.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := ProbeSession.new()
	root.add_child(game)
	game.set_process(false)
	for trial: Array in [[0, false, false, 405], [0, true, true, 205], [1, false, false, 205],
		[1, true, true, 105], [2, true, false, 405], [3, true, false, 205], [9, true, true, 205]]:
		game.phase = "world"
		game.player.direction = 2
		game.outstanding = -1
		game.next_walk = 0
		game._handle(PackedByteArray([0xbf, 0, 6, 0, 0x26, trial[0]]))
		assert(game.walk(2, trial[1]))
		assert(game.sent.size() == 7 and game.sent[0] == 2)
		assert(((int(game.sent[1]) & 0x80) != 0) == trial[2] and game.running == trial[2])
		assert(game.move_interval == trial[3])
		game.outstanding = -1
		game.next_walk = 0
		assert(game.walk(3, trial[1]) and game.move_interval == 20)
	assert(not game.unhandled_extended.has(0x26))
	game._handle(PackedByteArray([0xbf, 0, 6, 0, 0x26, 2]))
	game._handle(PackedByteArray([0xbf, 0, 5, 0, 0x26]))
	assert(game.speed_control == 2)
	game.close()
	assert(game.speed_control == 0)
	game.queue_free()
	await process_frame
	print("SPEED CONTROL: effective run flag, step cadence, turns and reset pass")
	quit()
