# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Wire := preload("res://Network/LoginProtocol.gd")
const SERIAL := 0x105
const BODY := 267

func _initialize() -> void:
	create_timer(60.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	assert(world.enhanced_creature_actions == enhanced)
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	var checks := 0
	for flags: int in [0, 0x40]:
		world.game._handle(mobile_packet(at, flags))
		var avatar: Node3D = world.avatars[SERIAL]
		var expected := "TroglodyteSway"
		if enhanced:
			expected = "TroglodyteSettleFidget" if flags == 0 else "TroglodyteRaisedFidget"
		world.game._handle(action_packet(5))
		assert(avatar.horse_visual.current_clip == expected)
		world.game._handle(action_packet(8))
		assert(avatar.horse_visual.current_clip == ("TroglodyteOpenReach" if enhanced else "Pillage"))
		assert(avatar.horse_visual.native_body == BODY and avatar.horse_visual.native_hue == 1109)
		checks += 3
	print("WORLD CREATURE DISPATCH: ", checks, " checks, Enhanced profile ", enhanced)
	world.queue_free()
	await process_frame
	quit()

func mobile_packet(at: Vector2i, flags: int) -> PackedByteArray:
	var bytes := PackedByteArray([0x77])
	bytes.append_array(Wire.uint_be(SERIAL, 4))
	bytes.append_array(Wire.uint_be(BODY, 2))
	bytes.append_array(Wire.uint_be(at.x, 2))
	bytes.append_array(Wire.uint_be(at.y, 2))
	bytes.append_array(PackedByteArray([0, 0]))
	bytes.append_array(Wire.uint_be(1109, 2))
	bytes.append_array(PackedByteArray([flags, 1]))
	return bytes

func action_packet(kind: int) -> PackedByteArray:
	var bytes := PackedByteArray([0xe2])
	bytes.append_array(Wire.uint_be(SERIAL, 4))
	bytes.append_array(PackedByteArray([0, kind, 0, 0, 1]))
	return bytes
