# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Leech := preload("res://Presentation/SourceMeerEternalEffects.gd")
const Caster := 0x4402
const Target := 0x4403


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	world.game._handle(mobile_packet(at, Caster, 772, 64))
	world.game._handle(mobile_packet(at + Vector2i(2, 0), Target, 211, 64))
	world.game.phase = "world"
	var caster: Node3D = world.avatars[Caster].horse_visual
	var presenter: Node3D
	for child in world.get_children():
		if child.has_method("_bolt_origin") and child.has_method("present"):
			presenter = child
			break
	assert(presenter != null)
	var incoming := effect(0, Caster, Target, 0x36fa, 9533, at)
	var before: int = presenter.get_child_count()
	world.game._handle(incoming)
	assert(caster.current_clip == "Cast" and presenter.get_child_count() == before + 1)
	caster.animator.advance(.15)
	var hand: Variant = caster.life_leech_hand()
	assert(hand is Vector3)
	var packet := effect(0, Caster, Target, 0x36fa, 9533, at)
	var parsed := preload("res://Network/Packets/Effects.gd").parse(packet)
	assert(Leech.bolt_origin(world, parsed).distance_to(hand) < .00001)
	parsed.tile = 9534
	assert(Leech.bolt_origin(world, parsed) == null)
	world.game._handle(effect(0, Target, Caster, 0x36f4, 9535, at))
	var returned := preload("res://Network/Packets/Effects.gd").parse(effect(0, Target, Caster, 0x36f4, 9535, at))
	assert(Leech.bolt_target(world, returned).distance_to(hand) < .00001)
	var hued := effect(0, Caster, Target, 0x36fa, 0, at)
	hued.resize(36)
	hued[0] = 0xc0
	hued[23] = 0
	hued[30] = 1108 >> 8
	hued[31] = 1108 & 255
	var fallback := preload("res://Network/Packets/Effects.gd").parse(hued)
	assert(Leech.bolt_origin(world, fallback).distance_to(hand) < .00001)
	fallback.hue = 0
	assert(Leech.bolt_origin(world, fallback) == null)
	caster.action_remaining = 0.0
	caster.play_gait(false, 0.0)
	assert(caster.current_clip == "Idle")
	world.game._handle(effect(3, Caster, 0, 0x376a, 9537, at))
	assert(caster.current_clip == "Cast")
	caster.dead = true
	assert(Leech.bolt_origin(world, preload("res://Network/Packets/Effects.gd").parse(packet)) == null)
	world.game.phase = "offline"
	print("MEER ETERNAL WORLD: 11 decoded presentation checks, Enhanced ",
		"--enhanced-creature-actions" in OS.get_cmdline_user_args())
	quit()


func effect(kind: int, source: int, target: int, graphic: int, particle: int, at: Vector2i) -> PackedByteArray:
	var packet := PackedByteArray([0xc7, kind])
	packet.append_array(Wire.uint_be(source, 4))
	packet.append_array(Wire.uint_be(target, 4))
	packet.append_array(Wire.uint_be(graphic, 2))
	packet.append_array(Wire.uint_be(at.x, 2))
	packet.append_array(Wire.uint_be(at.y, 2))
	packet.append(0)
	packet.append_array(Wire.uint_be(at.x + 2, 2))
	packet.append_array(Wire.uint_be(at.y, 2))
	packet.resize(47)
	packet[22] = 1
	packet[23] = 10
	packet[36] = particle >> 8
	packet[37] = particle & 255
	return packet
