# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Presenter := preload("res://Presentation/EnhancedCreatureEffects.gd")


class FixtureWorld extends Node3D:
	var game := {"phase": "world"}
	var avatars := {}


func _initialize() -> void:
	create_timer(4.0).timeout.connect(func(): quit(2))
	call_deferred("run")


func run() -> void:
	var world := FixtureWorld.new()
	root.add_child(world)
	var subject := Node3D.new()
	world.add_child(subject)
	world.avatars[72] = subject
	var effects := Presenter.new()
	world.add_child(effects)
	effects.scene = world
	effects.present({"kind": "fixed_mobile", "source": 72, "target": 0, "graphic": 0x3728,
		"duration": 6, "speed": 0, "from": Vector3i.ZERO})
	assert(effects.get_child_count() == 2)
	var cloud := effects.get_child(0) as GPUParticles3D
	var lamp := effects.get_child(1) as OmniLight3D
	assert(cloud != null and lamp != null)
	subject.position = Vector3(3, 2, 1)
	await process_frame
	await process_frame
	assert(cloud.global_position == subject.global_position + Vector3.UP)
	assert(lamp.global_position == cloud.global_position)
	world.avatars.erase(72)
	subject.free()
	var last := cloud.global_position
	await process_frame
	assert(cloud.global_position == last)
	effects.queue_free()
	await create_timer(1.7).timeout
	assert(not is_instance_valid(cloud) and not is_instance_valid(lamp))
	print("ENHANCED EFFECT LIFETIME: smoke followed its target, held on removal and cleared with the presenter")
	quit()
