# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Hopper := preload("bake-skittering-hopper-enhanced.gd")
const Dancer := preload("bake-fan-dancer-enhanced.gd")
const Hue := preload("res://Presentation/HumanHue.gd")
const FanThrow := preload("test-fan-throw-world.gd")
const FirstSerial := 0x2210


static func cases() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for body: int in [302, 247]:
		var clips: Dictionary = Hopper.Clips if body == 302 else Dancer.Clips
		var flourish := 12 if body == 302 else 4
		var joints := ["bip01 head", "bip01 l hand", "bip01 r hand"]
		if body == 302:
			joints.append_array(Hopper.Wings.Joints)
		for info: Array in [[5, 0, 26, .48, 0x8035], [5, 1, 27, .56, 0x455],
				[8, 0, 28, .66, 0x489], [11, 0, flourish, .42, 0x8035], [15, 0, 23, .21, 0x455]]:
			var test := {"body": body, "type": info[0], "variant": info[1], "clip": clips[info[2]],
				"phase": info[3], "hue": info[4], "joints": joints, "visible": ["HopperWings"] if body == 302 else ["Body"]}
			if body == 302 and info[2] == 12:
				test.recolour = true
			result.append(test)
	return result


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var tests := cases()
	var result := await Replay.run(driver, world, at, enhanced, FirstSerial, tests)
	if enhanced:
		for info: Dictionary in tests:
			if info.body != 302:
				continue
			var holder: Node3D = world.world_items.nodes[result.rows[info.clip].corpse]
			var wings := holder.get_node("CorpseVisual/HopperWings") as MeshInstance3D
			var shader := wings.get_active_material(1) as ShaderMaterial
			var recoloured: bool = info.get("recolour", false) and "--recolour-optional-props" in OS.get_cmdline_user_args()
			var hue: int = 0x489 if recoloured else info.hue
			assert(shader != null and shader.get_shader_parameter("membrane"))
			assert(shader.get_shader_parameter("hue_palette") == Hue.palette(hue))
			assert(shader.get_shader_parameter("partial_hue") == ((hue & 0x8000) != 0))
			result.checks += 3
	result.checks += await FanThrow.check(driver, world, at, enhanced)
	return result
