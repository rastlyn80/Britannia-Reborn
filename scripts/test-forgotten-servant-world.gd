# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-ordinary-horse-world.gd"

const Corpses := preload("res://Presentation/CorpseModels.gd")
const Hue := preload("res://Presentation/HumanHue.gd")
const Wardrobe := preload("res://Presentation/HumanWardrobe.gd")
const SkinHue := 768
const NeutralHue := 1823
const HairHue := 1129
const Weapons := {0x0f61: 1, 0x1441: 1, 0x0f5e: 1, 0x0f49: 2, 0x13b4: 1, 0x0f52: 1, 0x0f62: 2}
const Hair := [0x203b, 0x203c, 0x203d, 0x2044, 0x2045, 0x2047, 0x2049, 0x204a]


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	for body: int in [400, 401]:
		if not await verify_outfit(world, at, body):
			return
	if not await verify_tyball_shroud(world, at):
		return
	if not check_skin_presets():
		return
	print("FORGOTTEN SERVANT WORLD: ", checks, " checks, Enhanced ", world.enhanced_creature_actions)
	quit(0)


func verify_outfit(world: Node, at: Vector2i, body: int) -> bool:
	var serial := 0x476e0 + body
	var wire := mobile_packet(at, serial, body, 0)
	wire[13] = SkinHue >> 8
	wire[14] = SkinHue & 255
	world.game._handle(wire)
	var avatar: Node3D = world.avatars[serial]
	var visual: Node3D = avatar.human_visual
	if not expect(visual != null and visual.female == (body == 401) and visual.skin_hue == SkinHue,
			"Body, sex and raw body hue are present on the human rig"):
		return false
	if not expect(visual.skin.get_shader_parameter("use_form_hue") == true
			and visual.skin.get_shader_parameter("form_hue_palette") == Hue.palette(SkinHue),
			"The authored skin receives the server's full body palette"):
		return false
	var clothes: Array = [
		[3, 0x170b, NeutralHue, "/part-boots.glb"],
		[5, 0x1efd, 0, "/shirt.glb"],
		[6, 0x1540, 0, "/bandana.glb"],
		[23 if body == 401 else 4, 0x1516 if body == 401 else 0x152e,
			NeutralHue + 1, "/skirt.glb" if body == 401 else "/part-pants.glb"],
	]
	for clothing: Array in clothes:
		world.game._handle(item_packet(serial, int(clothing[0]), int(clothing[1]), int(clothing[2])))
	for clothing: Array in clothes:
		var part := garment(visual, clothing[3])
		if not expect(part != null, "Wardrobe mesh for " + str(clothing[3])):
			return false
		var dye := int(clothing[2])
		if dye and not expect(has_palette(part, dye), "Neutral cloth dye uses its own palette"):
			return false
	var styles := Hair + [0x2046 if body == 401 else 0x2048]
	for hair: int in styles:
		world.game._handle(item_packet(serial, 11, hair, HairHue))
		if not expect(visual.native_cosmetics.hair_id == hair and visual.native_cosmetics.hair_hue == HairHue
				and visual.native_cosmetics.hair_family_mapped == Wardrobe.HAIR.has(hair),
				"Randomized hair identity and dye survive decoding"):
			return false
	for graphic: int in Weapons:
		var layer: int = Weapons[graphic]
		world.game._handle(item_packet(serial, layer, graphic, 0))
		var asset: String = Wardrobe.extra(graphic)[1]
		if not expect(visual.unsupported_items.is_empty() and not visual.missing_art.has(graphic)
				and garment(visual, "/" + asset.get_file() + ".glb") != null and visual.grip.holding,
				"Weapon mounts in the closed grip for graphic %04x" % graphic):
			return false
		if not expect(visual.animator.has_animation(visual.stance_clip("Walk")),
				"The equipped weapon has a walking stance"):
			return false
		var remove := PackedByteArray([0x1d])
		remove.append_array(Wire.uint_be(item_serial(serial, layer), 4))
		world.game._handle(remove)
	world.game._handle(item_packet(serial, 11, 0x203c, HairHue))
	world.game._handle(item_packet(serial, 1, 0x0f61, 0))
	var worn: Array = visual.server_equipment.duplicate(true)
	var corpse := 0x40000000 + serial
	world.game._handle(corpse_packet(at, corpse, body, SkinHue))
	world.game._handle(death_packet(serial, corpse))
	var state: Dictionary = world.creature_deaths.active.get(serial, {})
	if not expect(not state.is_empty(), "The ordinary death packet starts the human collapse"):
		return false
	var dying: Node3D = state.visual
	if not expect(dying.server_equipment == worn and dying.skin.get_shader_parameter("use_form_hue") == true,
			"The collapse keeps the outfit and exact palette"):
		return false
	world.creature_deaths.finish(serial)
	await process_frame
	var frozen: Node3D = world.world_items.nodes[corpse].get_node_or_null("CorpseVisual")
	return expect(frozen != null and frozen.get_meta("corpse_body") == body and frozen.get_meta("native_hue") == SkinHue
			and frozen.get_meta("graphic_id") == Corpses.GRAPHIC
			and frozen.find_children("*", "Skeleton3D", true, false).is_empty(),
			"The ordinary corpse graphic freezes the fitted outfit")


func verify_tyball_shroud(world: Node, at: Vector2i) -> bool:
	const Body := 400
	const HueId := 0x455
	const Shroud := 0x2684
	const Serial := 0x476e3
	const Corpse := 0x40000000 + Serial
	var wire := mobile_packet(at, Serial, Body, 0)
	wire[13] = HueId >> 8
	wire[14] = HueId & 255
	world.game._handle(wire)
	world.game._handle(item_packet(Serial, 22, Shroud, HueId))
	var visual: Node3D = world.avatars[Serial].human_visual
	var hood := garment(visual, "/part-hood.glb")
	var robe := garment(visual, "/part-robe.glb")
	if not expect(visual.skin_hue == HueId and visual.unsupported_items.is_empty()
			and hood != null and hood.visible and robe != null and robe.visible,
			"Tyball's native outfit shows the hood and robe on the human rig"):
		return false
	if not expect(has_palette(hood, HueId) and has_palette(robe, HueId),
			"Both shroud pieces receive the native dye"):
		return false
	world.game._handle(corpse_packet(at, Corpse, Body, HueId))
	world.game._handle(death_packet(Serial, Corpse))
	var death: Dictionary = world.creature_deaths.active.get(Serial, {})
	if not expect(not death.is_empty() and death.visual.server_equipment == visual.server_equipment,
			"Tyball's collapse retains the hooded outfit"):
		return false
	world.creature_deaths.finish(Serial)
	await process_frame
	var frozen: Node3D = world.world_items.nodes[Corpse].get_node_or_null("CorpseVisual")
	return expect(frozen != null and frozen.get_meta("graphic_id") == Corpses.GRAPHIC
			and frozen.get_meta("corpse_body") == Body and frozen.get_meta("native_hue") == HueId
			and frozen.find_children("*", "Skeleton3D", true, false).is_empty(),
			"Tyball's dyed human outfit hands off to the static corpse")


func check_skin_presets() -> bool:
	var body_hue := preload("res://Presentation/HumanBodyHue.gd")
	var material := ShaderMaterial.new()
	material.shader = preload("res://Presentation/FreeHumanSkin.gdshader")
	for hue: int in [0, 1002, 1034, 1058, 0x8035]:
		body_hue.apply(material, hue, "", true)
		if not expect(material.get_shader_parameter("use_form_hue") == false,
				"Default, natural and partial skin hues retain the authored preset"):
			return false
	body_hue.apply(material, 0x847e, "vampiric", false)
	if not expect(material.get_shader_parameter("form_hue_palette") == Hue.palette(0x847e),
			"Vampiric palette remains available with its original native hue"):
		return false
	body_hue.apply(material, 1002, "", true)
	return expect(material.get_shader_parameter("use_form_hue") == false,
		"Returning to a natural hue clears the equipped form palette")


func item_serial(owner: int, layer: int) -> int:
	return 0x40000000 + owner * 32 + layer


func item_packet(owner: int, layer: int, graphic: int, hue: int) -> PackedByteArray:
	var bytes := PackedByteArray([0x2e])
	bytes.append_array(Wire.uint_be(item_serial(owner, layer), 4))
	bytes.append_array(Wire.uint_be(graphic, 2))
	bytes.append_array(PackedByteArray([0, layer]))
	bytes.append_array(Wire.uint_be(owner, 4))
	bytes.append_array(Wire.uint_be(hue, 2))
	return bytes


func garment(visual: Node3D, suffix: String) -> MeshInstance3D:
	for mesh: MeshInstance3D in visual.parts:
		if str(mesh.get_meta("source_path", "")).ends_with(suffix):
			return mesh
	return null


func has_palette(part: MeshInstance3D, dye: int) -> bool:
	for surface in part.mesh.get_surface_count():
		var material := part.get_active_material(surface) as ShaderMaterial
		if material != null and material.get_shader_parameter("hue_palette") == Hue.palette(dye):
			return true
	return false
