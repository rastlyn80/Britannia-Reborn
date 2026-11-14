# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-later-creature-world.gd"

const Named := [
	["Flurry", 13, 3], ["Mistral", 13, 924], ["Tempest", 13, 1175],
	["Grim", 60, 1744], ["Grim", 61, 1744], ["Greater Poison Elemental", 162, 667],
]
const Hues := preload("res://Presentation/HumanHue.gd")


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	if not expect(world.enhanced_creature_actions == enhanced, "World uses the requested action profile"):
		return
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	for index in Named.size():
		var row: Array = Named[index]
		for fall in 2:
			if not await check_named(world, at, row, index * 2 + fall, fall):
				return
	print("NAMED LABYRINTH VISUALS: ", checks, " checks, ", Named.size() * 2,
		" decoded falls, Enhanced ", enhanced)
	quit(0)


func check_named(world: Node, at: Vector2i, row: Array, index: int, fall: int) -> bool:
	var label: String = row[0]
	var body: int = row[1]
	var hue: int = row[2]
	var serial := 0x37000 + index
	var corpse := 0x40000000 + serial
	create_actor(world, at, serial, body, 64, hue)
	var avatar: Node3D = world.avatars[serial]
	var actor: Node3D = avatar.horse_visual
	if not expect(actor != null and actor.native_body == body and actor.native_hue == hue,
			"%s body %d uses its native hue" % [label, body]):
		return false
	var palette := Hues.palette(hue)
	if not expect(palette != null and has_palette(actor, palette), "%s visible material applies the original palette" % label):
		return false
	var action := 12 if body in [60, 61] else 4
	classic_action(world, serial, action)
	if not expect(actor.current_clip != "Idle" and actor.animator.is_playing(),
			"%s dispatches a living combat action (%s)" % [label, actor.current_clip]):
		return false
	if body in [60, 61] and not expect(actor.current_clip == "DragonBreath", "Both Drake bodies play their breath clip"):
		return false
	classic_action(world, serial, fall + 2)
	if not expect(actor.dead, "%s starts the selected death animation" % label):
		return false
	var clip: String = actor.current_clip
	var remaining: float = actor.animator.current_animation_length
	actor.animator.seek(remaining * .25, true)
	if fall == 0:
		world.game._handle(corpse_packet(at, corpse, body, hue))
	world.game._handle(death_packet(serial, corpse))
	if fall != 0:
		world.game._handle(corpse_packet(at, corpse, body, hue))
	var transfer: Dictionary = world.creature_deaths.active.get(serial, {})
	var holder: Node3D = world.world_items.nodes[corpse]
	if not expect(not transfer.is_empty() and transfer.visual.current_clip == clip and not holder.visible,
			"%s fall continues through handoff (%s)" % [label, clip]):
		return false
	var dying: Node3D = transfer.visual
	dying.animator.seek(dying.animator.current_animation_length, true)
	world.creature_deaths._process(float(transfer.remaining) + .1)
	await process_frame
	var frozen: Node3D = holder.get_node_or_null("CorpseVisual")
	if not expect(frozen != null and holder.visible and frozen.get_meta("native_hue") == hue
			and frozen.get_meta("corpse_body") == body and frozen.get_meta("death_clip") == clip
			and frozen.find_children("*", "Skeleton3D", true, false).is_empty()
			and has_palette(frozen, palette),
			"%s freezes the selected fall with its native palette" % label):
		return false
	print("NAMED FALL: ", label, " body ", body, " hue ", hue, " ", clip)
	return true


func has_palette(model: Node3D, palette: Texture2D) -> bool:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree() or mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as ShaderMaterial
			if material != null and material.get_shader_parameter("use_hue") == true \
					and material.get_shader_parameter("hue_palette") == palette:
				return true
	return false

