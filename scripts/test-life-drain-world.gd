# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Drain := preload("res://Presentation/SourceLifeDrainNotice.gd")
const Target := 0x4644
const Observer := 0x4645


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
	world.game._handle(notice(Drain.Start))
	var particles := target.get_node_or_null(Drain.Marker) as GPUParticles3D
	assert(particles != null and observer.get_node_or_null(Drain.Marker) == null)
	var expiry := particles.get_node("DrainDuration") as Timer
	expiry.start(1.0)
	world.game._handle(notice(Drain.Refresh))
	assert(target.get_node_or_null(Drain.Marker) == particles and expiry.time_left > 5.0)
	world.game._handle(notice(Drain.End))
	assert(particles.is_queued_for_deletion())
	world.game._handle(notice(Drain.Start))
	var restarted := target.get_node_or_null(Drain.Marker) as GPUParticles3D
	assert(restarted != null and restarted != particles)
	world.game._handle(notice(Drain.End))
	world.game.phase = "offline"
	await process_frame
	await process_frame
	assert(target.get_node_or_null(Drain.Marker) == null)
	world.game._handle(notice(Drain.Start))
	assert(target.get_node_or_null(Drain.Marker) == null)
	world.game.phase = "world"
	world.game._handle(notice(Drain.Start))
	particles = target.get_node_or_null(Drain.Marker) as GPUParticles3D
	assert(particles != null)
	expiry = particles.get_node("DrainDuration") as Timer
	expiry.timeout.emit()
	assert(particles.is_queued_for_deletion())
	world.game.phase = "offline"
	print("LIFE DRAIN WORLD: 8 decoded target effect checks, Enhanced ",
		"--enhanced-creature-actions" in OS.get_cmdline_user_args())
	quit()


func notice(cliloc: int) -> PackedByteArray:
	var packet := PackedByteArray([0xc1, 0, 50])
	packet.append_array(Wire.uint_be(0xffffffff, 4))
	packet.append_array(PackedByteArray([0xff, 0xff, 6, 0, 0x3b, 0, 3]))
	packet.append_array(Wire.uint_be(cliloc, 4))
	packet.resize(50)
	return packet
