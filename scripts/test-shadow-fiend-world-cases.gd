# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Body := 168
const Joints := ["bip01 head", "bip01 r hand", "imp_l_wing 02", "bip01 l foot"]
const Cases := [
	{"type": 11, "variant": 2, "clip": "ShadowFiendRaisedClaws", "phase": .43, "hue": 0x8035},
	{"type": 15, "variant": 0, "clip": "ShadowFiendManifest", "phase": .23, "hue": 53},
	{"type": 5, "variant": 1, "clip": "ShadowFiendTwistedGuard", "phase": .39, "hue": 0x455},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var rows := {}
	for info: Dictionary in Cases:
		var result := await witness(driver, world, at, enhanced, info, 0x2588 + rows.size())
		assert(not result.is_empty())
		rows[info.clip] = result
	return {"rows": rows, "checks": rows.size() * (8 if enhanced else 6)}


static func witness(driver, world: Node, at: Vector2i, enhanced: bool, info: Dictionary, serial: int) -> Dictionary:
	var corpse := 0x40000000 + serial
	world.game._handle(driver.mobile_packet(at, 64, serial, Body, info.hue))
	var source: Node3D = world.avatars[serial].horse_visual
	assert(source.native_body == Body and source.native_hue == info.hue)
	var original_pose: Array[Vector3] = []
	if enhanced:
		world.game._handle(driver.action_packet(info.type, serial, info.variant))
		assert(source.current_clip == info.clip)
		source.animator.advance(.10)
		source.animator.seek(source.animator.current_animation_length * info.phase, true)
		source._physics_process(1.0 / 60.0)
		for joint: String in Joints:
			original_pose.append(Replay.point(source, joint))
	var effects: Array[Dictionary] = []
	var observe := func(effect: Dictionary): effects.append(effect)
	var module: RefCounted = world.game.module("effects")
	module.spawned.connect(observe)
	world.game._handle(effect_packet(at))
	module.spawned.disconnect(observe)
	assert(effects.size() == 1 and effects[0].kind == "fixed_location" and effects[0].graphic == 0x376a)
	assert(effects[0].from == Vector3i(at.x, at.y, 0))
	if serial % 2 == 0:
		world.game._handle(driver.corpse_packet(at, corpse, Body, info.hue))
	var death := PackedByteArray([0xaf])
	death.append_array(Wire.uint_be(serial, 4))
	death.append_array(Wire.uint_be(corpse, 4))
	death.append_array(Wire.uint_be(0, 4))
	world.game._handle(death)
	if serial % 2 != 0:
		world.game._handle(driver.corpse_packet(at, corpse, Body, info.hue))
	var state: Dictionary = world.creature_deaths.active[serial]
	var fallen: Node3D = state.visual
	assert(fallen.current_clip == "Death" and fallen.native_hue == info.hue)
	for index in original_pose.size():
		assert(original_pose[index].distance_to(Replay.point(fallen, Joints[index])) < .002)
	assert(world.creature_deaths.held_corpses[corpse] == serial and not world.world_items.nodes[corpse].visible)
	world.game._handle(remove_packet(corpse))
	world.game._handle(remove_packet(serial))
	assert(state.corpse == 0 and not world.creature_deaths.held_corpses.has(corpse))
	await driver.create_timer(float(state.remaining) + .17).timeout
	assert(not world.avatars.has(serial) and not world.creature_deaths.active.has(serial))
	assert(not world.world_items.nodes.has(corpse) and not world.world_items.corpse_snapshots.has(corpse))
	return {"body": Body, "hue": info.hue, "removed": corpse}


static func remove_packet(serial: int) -> PackedByteArray:
	var packet := PackedByteArray([0x1d])
	packet.append_array(Wire.uint_be(serial, 4))
	return packet


static func effect_packet(at: Vector2i) -> PackedByteArray:
	var packet := PackedByteArray([0x70, 2, 0, 0, 0, 0, 0, 0, 0, 0])
	packet.append_array(Wire.uint_be(0x376a, 2))
	for unused in 2:
		packet.append_array(Wire.uint_be(at.x, 2))
		packet.append_array(Wire.uint_be(at.y, 2))
		packet.append(0)
	packet.append_array(PackedByteArray([10, 1, 0, 0, 0, 0]))
	return packet
