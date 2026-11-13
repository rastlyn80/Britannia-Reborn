# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Poison := preload("res://Presentation/SourceBetrayerPoison.gd")
const Caster := 0x4501
const Other := 0x4502


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	for child in world.get_children():
		if child.get_script() == preload("res://Network/MobileNames.gd"):
			child.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	world.game._handle(mobile_packet(at, Caster, 767, 64))
	world.game._handle(mobile_packet(at + Vector2i(2, 0), Other, 772, 64))
	world.game.phase = "world"
	var caster: Node3D = world.avatars[Caster].horse_visual
	assert(caster.poison_socket == caster.skeleton.find_bone("bip01 l hand"))
	var presenter: Node3D
	for child in world.get_children():
		if child.has_method("_bolt_origin") and child.has_method("present"):
			presenter = child
			break
	assert(presenter != null)
	var before: int = presenter.get_child_count()
	world.game._handle(packet(at, Caster, true))
	assert(presenter.get_child_count() == before + 2)
	var gas := presenter.get_child(before) as GPUParticles3D
	assert(not gas.local_coords and gas.global_position.distance_to(caster.poison_gas_origin()) < .00001)
	assert(gas.draw_pass_1.material.albedo_color.is_equal_approx(presenter.COLOURS.poison))
	world.avatars[Caster].position.x += .12
	await process_frame
	await process_frame
	assert(gas.global_position.distance_to(caster.poison_gas_origin()) < .00001)
	var plain := packet(at, Caster, false)
	world.game._handle(plain)
	assert(presenter.get_child(before + 2).global_position.distance_to(caster.poison_gas_origin()) < .00001)
	var invalid := packet(at, Caster, true)
	invalid[46] = 1
	assert(Poison.source(world, preload("res://Network/Packets/Effects.gd").parse(invalid)) == null)
	assert(Poison.source(world, preload("res://Network/Packets/Effects.gd").parse(packet(at, Other, true))) == null)
	world.game.phase = "offline"
	print("BETRAYER WORLD: 9 decoded poison checks, Enhanced ", "--enhanced-creature-actions" in OS.get_cmdline_user_args())
	quit()


func packet(at: Vector2i, serial: int, particle: bool) -> PackedByteArray:
	var result := PackedByteArray([0xc7 if particle else 0xc0, 3])
	result.append_array(Wire.uint_be(serial, 4))
	result.append_array(Wire.uint_be(0, 4))
	result.append_array(Wire.uint_be(0x376a, 2))
	for index in 2:
		result.append_array(Wire.uint_be(at.x, 2))
		result.append_array(Wire.uint_be(at.y, 2))
		result.append(0)
	result.resize(47 if particle else 36)
	result[22] = 9
	result[23] = 32
	if particle:
		result[36] = 0x25
		result[37] = 0x39
		result[46] = 2
	return result
