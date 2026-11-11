# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Wire := preload("res://Network/LoginProtocol.gd")
const Effects := preload("res://Presentation/CreatureProjectilePresenter.gd")
const EnhancedEffects := preload("res://Presentation/SourceEnhancedCreatureProjectilePresenter.gd")
const Tessen := preload("res://Presentation/SourceTessenMesh.gd")
const Serial := 0x2350


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> int:
	at += Vector2i(4, 4)
	var effects: Node3D
	for child: Node in world.get_children():
		if child is Effects:
			effects = child
			break
	assert(effects != null)
	assert((effects is EnhancedEffects) == enhanced)
	var origin := Vector3i(at.x, at.y, 0)
	var target := origin + Vector3i(5, 0, 0)
	world.game._handle(driver.mobile_packet(at, 64, Serial, 247, 0x8035))
	var previous := effects.get_child_count()
	var native_packet := packet(origin, target)
	if not enhanced:
		deliver(world, native_packet)
		assert(effects.get_child_count() == previous + 1 and effects.get_child(previous).mesh is SphereMesh)
		return 2
	var actor: Node3D = world.avatars[Serial].horse_visual
	world.game._handle(driver.action_packet(11, Serial, 0))
	actor.animator.advance(.30)
	assert(actor.current_clip == "FanDancerSteppingSweep")
	var captured := Tessen.capture(actor, 0)
	assert(not captured.is_empty())
	var prior_tweens: Array[Tween] = world.get_tree().get_processed_tweens()
	deliver(world, native_packet)
	assert(effects.get_child_count() == previous + 1)
	var fan := effects.get_child(previous) as MeshInstance3D
	assert(fan.name == "NativeFanThrow" and fan.mesh is ArrayMesh and fan.mesh.surface_get_array_len(0) == 576)
	assert(fan.global_position.is_equal_approx(captured.centre))
	assert(fan.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == captured.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	var material := fan.mesh.surface_get_material(0) as ShaderMaterial
	assert(material != null and not material.get_shader_parameter("use_hue"))
	var flight: Tween
	for tween: Tween in world.get_tree().get_processed_tweens():
		if tween not in prior_tweens:
			assert(flight == null)
			flight = tween
	assert(flight != null)
	flight.pause()
	flight.custom_step(.08)
	assert(is_instance_valid(fan) and fan.global_position.distance_to(captured.centre) > .05
		and not fan.global_basis.is_equal_approx(Basis.IDENTITY))
	flight.custom_step(1.6)
	await driver.process_frame
	assert(not is_instance_valid(fan))
	world.game._handle(driver.mobile_packet(at, 64, Serial + 1, 247, 0))
	previous = effects.get_child_count()
	deliver(world, native_packet)
	assert(effects.get_child_count() == previous + 1 and effects.get_child(previous).mesh is SphereMesh)
	previous = effects.get_child_count()
	deliver(world, packet(origin + Vector3i(0, 0, 1), target))
	assert(effects.get_child_count() == previous + 1 and effects.get_child(previous).mesh is SphereMesh)
	return 11


static func deliver(world: Node, bytes: PackedByteArray) -> void:
	var phase: String = world.game.phase
	world.game.phase = "world"
	world.game._handle(bytes)
	world.game.phase = phase


static func packet(origin: Vector3i, destination: Vector3i) -> PackedByteArray:
	var bytes := PackedByteArray([0x70, 0])
	bytes.append_array(Wire.uint_be(0, 4))
	bytes.append_array(Wire.uint_be(0, 4))
	bytes.append_array(Wire.uint_be(0x27a3, 2))
	for at: Vector3i in [origin, destination]:
		bytes.append_array(Wire.uint_be(at.x, 2))
		bytes.append_array(Wire.uint_be(at.y, 2))
		bytes.append(at.z & 0xff)
	bytes.append_array(PackedByteArray([10, 0, 0, 0, 0, 0]))
	return bytes
