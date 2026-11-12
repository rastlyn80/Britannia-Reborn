# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-enhanced-world-dispatch.gd"

const Daemon := preload("res://Presentation/SourceTerrainDaemonVisual.gd")
const Wyvern := preload("res://Presentation/SourceTerrainWyvernVisual.gd")
const Cases := preload("res://../scripts/test-daemon-wyvern-world.gd")


func run() -> void:
	var world := make_world()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	assert(world.enhanced_creature_actions == enhanced)
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	var serial := 0x18d0
	world.game._handle(mobile_packet(at, 64, serial, 9, 0x8035))
	var daemon := world.avatars[serial].horse_visual as Daemon
	assert(daemon != null and daemon.support_extent == Vector2(2.6, 2.45) and daemon.flight_clearance == .98)
	world.game._handle(mobile_packet(at, 64, serial + 1, 62, 0x455))
	var wyvern := world.avatars[serial + 1].horse_visual as Wyvern
	assert(wyvern != null and wyvern.native_body == 62 and wyvern.native_hue == 0x455)
	for pair: Array in [[15, "WingRecoil"], [18, "WingRear"], [19, "Fly"], [20, "Land"]]:
		world.game._handle(classic_packet(pair[0], serial + 1))
		assert(wyvern.current_clip == pair[1], "%s selected %s" % [pair[0], wyvern.current_clip])
	var receipt: Dictionary = await Cases.check(self, world, at, enhanced)
	assert(receipt.rows.size() == 4 and receipt.checks == (32 if enhanced else 24))
	print("WINGED TERRAIN WORLD: ", receipt.checks + 9, " action and corpse checks, Enhanced ", enhanced)
	world.queue_free()
	await process_frame
	quit()


func classic_packet(group: int, serial: int) -> PackedByteArray:
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(Wire.uint_be(group, 2))
	packet.append_array(PackedByteArray([0, 5, 0, 1, 1, 0, 0]))
	return packet
