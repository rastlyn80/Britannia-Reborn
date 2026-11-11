# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Effects := preload("res://Presentation/CreatureProjectilePresenter.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Joints := ["bip01 head", "bip01 l hand", "bone_lrip06", "bip01 r foot"]
const Cases := [
	{"body": 303, "type": 11, "variant": 2, "clip": "DevourerRaisedCast", "phase": .43,
		"hue": 0x8035, "joints": Joints, "recolour": true},
	{"body": 303, "type": 15, "clip": "DevourerWakeUnfold", "phase": .31, "hue": 0x455, "joints": Joints},
	{"body": 303, "type": 5, "variant": 1, "flags": 0, "clip": "DevourerLowInspection",
		"phase": .44, "hue": 0x489, "joints": Joints},
]
const Caster := 0x2564
const Target := 0x2565


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var result := await Replay.run(driver, world, at, enhanced, 0x2560, Cases)
	result.checks += check_spell(driver, world, at + Vector2i(2, 2), enhanced)
	return result


static func check_spell(driver, world: Node, at: Vector2i, enhanced: bool) -> int:
	var effects: Node3D
	for child: Node in world.get_children():
		if child is Effects:
			effects = child
			break
	assert(effects != null)
	var target := at + Vector2i(2, 0)
	world.game._handle(driver.mobile_packet(at, 64, Caster, 303, 0x8035))
	world.game._handle(driver.mobile_packet(target, 64, Target, 734, 0))
	var actor: Node3D = world.avatars[Caster].horse_visual
	var previous: int = effects.get_child_count()
	var prior: Array[Tween] = world.get_tree().get_processed_tweens()
	var phase: String = world.game.phase
	world.game.phase = "world"
	world.game._handle(spell_packet(at, target))
	world.game.phase = phase
	if not enhanced:
		assert(effects.get_child_count() == previous + 1)
		assert(effects.get_child(previous).mesh is SphereMesh and actor.current_clip != "DevourerRaisedCast")
		return 4
	assert(actor.current_clip == "DevourerRaisedCast" and effects.get_child_count() == previous)
	var cue: Tween
	for tween: Tween in world.get_tree().get_processed_tweens():
		if tween not in prior:
			assert(cue == null)
			cue = tween
	assert(cue != null)
	cue.pause()
	actor.animator.advance(.40)
	var origin: Vector3 = actor.magic_arrow_origin()
	cue.custom_step(.42)
	assert(effects.get_child_count() == previous + 1)
	var projectile := effects.get_child(previous) as MeshInstance3D
	assert(projectile.mesh is SphereMesh and projectile.global_position.distance_to(origin) < .001)
	return 6


static func spell_packet(origin: Vector2i, target: Vector2i) -> PackedByteArray:
	var bytes := PackedByteArray([0x70, 0])
	bytes.append_array(Wire.uint_be(Caster, 4))
	bytes.append_array(Wire.uint_be(Target, 4))
	bytes.append_array(Wire.uint_be(0x36e4, 2))
	for point: Vector2i in [origin, target]:
		bytes.append_array(Wire.uint_be(point.x, 2))
		bytes.append_array(Wire.uint_be(point.y, 2))
		bytes.append(0)
	bytes.append_array(PackedByteArray([5, 0, 0, 0, 0, 0]))
	return bytes
