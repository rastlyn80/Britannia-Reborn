# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Body := 300
const Joints := ["bip01 head", "box72", "bone65", "bip01 r foot"]
const Cases := [
	{"body": Body, "type": 11, "variant": 2, "clip": "CrystalShardCast", "phase": .43,
		"hue": 0x8035, "joints": Joints, "recolour": true},
	{"body": Body, "type": 15, "clip": "CrystalShardAssembly", "phase": .87, "hue": 53, "joints": Joints},
	{"body": Body, "type": 5, "variant": 1, "flags": 0, "clip": "CrystalLowInspection",
		"phase": .48, "hue": 0x455, "joints": Joints},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var result := await Replay.run(driver, world, at, enhanced, 0x25a8, Cases)
	if enhanced:
		await check_fragment_corpse(driver, world, at)
		result.checks += 10
	return result


static func check_fragment_corpse(driver, world: Node, at: Vector2i) -> void:
	const Serial := 0x25ac
	const Corpse := 0x40000000 + Serial
	const OldHue := 0x8035
	const NewHue := 0x489
	world.game._handle(driver.mobile_packet(at, 64, Serial, Body, OldHue))
	var actor: Node3D = world.avatars[Serial].horse_visual
	world.game._handle(driver.action_packet(15, Serial, 0))
	assert(actor.current_clip == "CrystalShardAssembly")
	actor.animator.advance(.10)
	actor.animator.seek(actor.animator.current_animation_length * .35, true)
	assert(actor.fragments.visible and not actor.body_mesh.visible)
	var positions := {}
	for part: MeshInstance3D in actor.fragments.get_children():
		positions[part.name] = part.global_transform
	var death := PackedByteArray([0xaf])
	death.append_array(Wire.uint_be(Serial, 4))
	death.append_array(Wire.uint_be(Corpse, 4))
	death.append_array(Wire.uint_be(0, 4))
	world.game._handle(death)
	world.game._handle(driver.corpse_packet(at, Corpse, Body, OldHue))
	var state: Dictionary = world.creature_deaths.active[Serial]
	var fallen: Node3D = state.visual
	assert(fallen.current_clip == "CrystalFragmentFall" and fallen.fragments.visible)
	for part: MeshInstance3D in fallen.fragments.get_children():
		assert(part.global_transform.is_equal_approx(positions[part.name]))
	var holder: Node3D = world.world_items.nodes[Corpse]
	assert(not holder.visible)
	await driver.create_timer(float(state.remaining) + .17).timeout
	var frozen: Node3D = holder.get_node("CorpseVisual")
	assert(holder.visible and frozen.get_child_count() == 8 and frozen.get_meta("death_clip") == "CrystalFragmentFall")
	assert(frozen.get_meta("native_hue") == OldHue and frozen.get_meta("corpse_body") == Body)
	var prior_bounds: AABB = frozen.get_meta("corpse_bounds")
	var prior_pose := frozen.global_transform
	world.game._handle(driver.corpse_packet(at, Corpse, Body, NewHue))
	holder = world.world_items.nodes[Corpse]
	frozen = holder.get_node("CorpseVisual")
	assert(frozen.get_child_count() == 8 and frozen.get_meta("native_hue") == NewHue)
	assert(frozen.global_transform.is_equal_approx(prior_pose) and frozen.get_meta("corpse_bounds") == prior_bounds)
	var palette := preload("res://Presentation/HumanHue.gd").palette(NewHue)
	assert(palette != null)
	for part: MeshInstance3D in frozen.get_children():
		var material := part.get_active_material(0) as ShaderMaterial
		assert(material != null and material.get_shader_parameter("hue_palette") == palette)
	assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
