# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Mage := preload("res://Presentation/SourceEnhancedMeerMageVisual.gd")
const Effects := preload("res://Presentation/SourceEnhancedMeerMageEffects.gd")
const Fit := preload("bake-meer-mage-enhanced.gd")
const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Subject := 8
const Target := 9

class WorldTrial extends Node3D:
	var game: Node
	var avatars := {}


func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	call_deferred("run")


func run() -> void:
	var world := WorldTrial.new()
	root.add_child(world)
	var game := Game.new()
	world.game = game
	world.add_child(game)
	game.set_process(false)
	game.phase = "world"
	var actor := Mage.new()
	actor.entry = Registry.entry(770).duplicate(true)
	actor.entry.assets.modern = Fit.Destination + "770-modern.scn"
	world.add_child(actor)
	actor.apply_identity(770, 0)
	actor.set_process(false)
	actor.set_physics_process(false)
	var caster := Avatar.new()
	caster.horse_visual = actor
	world.avatars[Subject] = caster
	var target := Avatar.new()
	world.add_child(target)
	target.set_process(false)
	target.set_physics_process(false)
	world.avatars[Target] = target
	var effects := Effects.new()
	world.add_child(effects)
	effects.configure(world)
	var checks := 0
	for cliloc: int in Mage.ForestCalls:
		actor.play("Idle", 0.0)
		actor.current_clip = "Idle"
		game._handle(notice(Subject, 770, 0, cliloc))
		assert(actor.current_clip == "Cast" and actor.action_remaining > 0.0)
		checks += 1
	game._handle(effect(false, 0))
	var cloud := target.get_node_or_null(Effects.CloudName) as Effects.Swarm
	assert(cloud != null and cloud.get_parent() == target and cloud.multimesh.instance_count == Effects.Swarm.Count)
	var point := cloud.global_position
	target.position += Vector3(1.5, .7, -.2)
	assert(cloud.global_position.distance_to(point + Vector3(1.5, .7, -.2)) < .0001)
	checks += 2
	cloud.remaining = .1
	game._handle(effect(true, 9539))
	assert(target.get_node(Effects.CloudName) == cloud and is_equal_approx(cloud.remaining, Effects.Swarm.Life))
	checks += 1
	game._handle(notice(Target, 400, 2, Effects.Dispersed))
	await process_frame
	assert(target.get_node_or_null(Effects.CloudName) == null)
	checks += 1
	game._handle(effect(true, 9538))
	assert(target.get_node_or_null(Effects.CloudName) == null)
	checks += 1
	game._handle(effect(true, 9539))
	assert(target.get_node_or_null(Effects.CloudName) != null)
	var death := PackedByteArray([0xaf])
	death.append_array(Wire.uint_be(Target, 4))
	death.append_array(Wire.uint_be(0x40000001, 4))
	death.append_array(Wire.uint_be(0, 4))
	game._handle(death)
	await process_frame
	assert(target.get_node_or_null(Effects.CloudName) == null)
	checks += 2
	caster.free()
	world.free()
	assert(checks == 9)
	print("MEER MAGE SWARM: ", checks, " decoded packet, cast and lifetime checks")
	quit()


func notice(serial: int, body: int, kind: int, cliloc: int) -> PackedByteArray:
	var bytes := PackedByteArray([0xc1, 0, 50])
	bytes.append_array(Wire.uint_be(serial, 4))
	bytes.append_array(Wire.uint_be(body, 2))
	bytes.append(kind)
	bytes.resize(14)
	bytes.append_array(Wire.uint_be(cliloc, 4))
	bytes.resize(50)
	return bytes


func effect(particles: bool, tile: int) -> PackedByteArray:
	var bytes := PackedByteArray([0xc7 if particles else 0xc0, 3])
	bytes.append_array(Wire.uint_be(Target, 4))
	bytes.append_array(Wire.uint_be(0, 4))
	bytes.append_array(Wire.uint_be(Effects.Graphic, 2))
	bytes.resize(36)
	bytes[22] = 10
	bytes[23] = 180
	if particles:
		bytes.append_array(Wire.uint_be(tile, 2))
		bytes.resize(49)
		bytes[46] = 3
	return bytes
