# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Wind := preload("res://Presentation/SourceSnowLadyWind.gd")
const Target := 0x4404
const Observer := 0x4405


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	world.game._handle(mobile_packet(at, Target, 400, 0))
	world.game._handle(mobile_packet(at + Vector2i(2, 0), Observer, 401, 0))
	world.game.player.serial = Target
	world.game.phase = "world"
	var target: Node3D = world.avatars[Target]
	var observer: Node3D = world.avatars[Observer]
	world.game._handle(notice(Wind.Start))
	var cloud := target.get_node_or_null(Wind.Name) as Wind.Wind
	assert(cloud != null and observer.get_node_or_null(Wind.Name) == null)
	cloud._process(2.0)
	assert(cloud.remaining < Wind.Duration)
	world.game._handle(notice(Wind.Refresh))
	assert(target.get_node_or_null(Wind.Name) == cloud and cloud.remaining == Wind.Duration)
	world.game._handle(notice(Wind.End))
	assert(cloud.is_queued_for_deletion())
	world.game.phase = "offline"
	await process_frame
	await process_frame
	assert(target.get_node_or_null(Wind.Name) == null)
	world.game.phase = "world"
	world.game._handle(notice(Wind.Start))
	cloud = target.get_node_or_null(Wind.Name) as Wind.Wind
	assert(cloud != null)
	cloud._process(Wind.Duration)
	assert(cloud.is_queued_for_deletion())
	world.game.phase = "offline"
	print("LADY OF THE SNOW WORLD: 8 decoded presentation checks, Enhanced ",
		"--enhanced-creature-actions" in OS.get_cmdline_user_args())
	quit()


func notice(cliloc: int) -> PackedByteArray:
	var packet := PackedByteArray([0xc1, 0, 50])
	packet.append_array(Wire.uint_be(0xffffffff, 4))
	packet.append_array(PackedByteArray([0xff, 0xff, 6, 0, 0x3b, 0, 3]))
	packet.append_array(Wire.uint_be(cliloc, 4))
	packet.resize(50)
	return packet
