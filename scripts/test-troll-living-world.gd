# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Visual := preload("res://Presentation/SourceLivingTrollVisual.gd")
const Selections := [[5, 0], [5, 1], [8, 0], [11, 0], [15, 0]]
const Motions := {
	53: ["TrollMeasure", "TrollOpenGuard", "TrollBraceAlert", "TrollOpenHandSlam", "TrollBraceAndRise"],
	54: ["TrollWatch", "TrollRaiseAxe", "TrollAlert", "TrollOverheadChop", "TrollRise"],
	55: ["FrostTrollKnuckleLook", "FrostTrollStaggerGuard", "FrostTrollWideAlert", "FrostTrollOpenPalm", "FrostTrollCrouchedRise"],
}
const ClassicProps := {53: "Axe", 54: "", 55: "FrostClub"}
const Props := ["Axe", "EnhancedAxe", "FrostClub"]


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	var serial := 0x5300
	for body: int in Motions:
		var default_prop: String = "EnhancedAxe" if body == 54 and enhanced else ClassicProps[body]
		for selection in (Selections.size() if enhanced else 2):
			world.game._handle(mobile_packet(at, serial, body, 0x40))
			var avatar: Node3D = world.avatars[serial]
			var actor: Node3D = avatar.horse_visual
			if not expect(actor is Visual and actor.native_body == body and held_prop(actor.model) == default_prop,
					"World selects the native body and its presentation weapon"):
				return
			world.game._handle(classic_packet(serial, 18))
			actor.animator.advance(.13)
			if not expect(actor.current_clip == "KnuckleCheck", "the Classic knuckle-check still has its own clip"):
				return
			avatar.animate(true, 0.0, .16, 5.5)
			if not expect(actor.current_clip == "Run", "movement interrupts the idle gesture"):
				return
			var expected_prop := default_prop
			if enhanced:
				var request: Array = Selections[selection]
				world.game._handle(action_packet(serial, request[0], request[1]))
				actor.animator.advance(.14)
				actor.animator.seek(.4 * actor.animator.current_animation_length, true)
				expected_prop = "EnhancedAxe" if body == 54 else ""
				if not expect(actor.current_clip == Motions[body][selection] and held_prop(actor.model) == expected_prop,
						"the Enhanced motion uses the weapon or bare hands from that body and group"):
					return
			else:
				world.game._handle(classic_packet(serial, 2 + selection))
				actor.animator.advance(.14)
				if not expect(actor.current_clip == ("Death2" if selection == 0 else "Death"),
						"the original Classic collapse group is still distinct"):
					return
			if not await verify_troll_corpse(world, at, serial, body, expected_prop, enhanced and body != 54):
				return
			serial += 1
	print("TROLL TERRAIN WORLD: ", checks, " checks, Enhanced ", enhanced)
	world.queue_free()
	await process_frame
	quit()


func verify_troll_corpse(world: Node3D, at: Vector2i, serial: int, body: int,
		expected_prop: String, unarmed: bool) -> bool:
	var corpse := 0x40003000 + serial
	if serial % 2 == 0:
		world.game._handle(corpse_packet(at, corpse, body, 0))
	world.game._handle(death_packet(serial, corpse))
	if serial % 2 != 0:
		world.game._handle(corpse_packet(at, corpse, body, 0))
	var transition: Dictionary = world.creature_deaths.active.get(serial, {})
	if not expect(not transition.is_empty() and transition.visual.unarmed_fall == unarmed
			and held_prop(transition.visual.model) == expected_prop, "death starts with the correct displayed prop"):
		return false
	await create_timer(float(transition.remaining) + .12).timeout
	var item: Node3D = world.world_items.nodes[corpse]
	var prior: Node3D = item.get_node("CorpseVisual")
	var placement := prior.global_transform
	var bounds: AABB = prior.get_meta("corpse_bounds")
	world.game._handle(corpse_packet(at, corpse, body, CorpseHue))
	item = world.world_items.nodes[corpse]
	var frozen: Node3D = item.get_node("CorpseVisual")
	return expect(item.visible and frozen.get_meta("corpse_body") == body
			and frozen.get_meta("native_hue") == CorpseHue
			and frozen.global_transform.is_equal_approx(placement) and frozen.get_meta("corpse_bounds") == bounds
			and held_prop(frozen) == expected_prop, "the static corpse keeps its posture, prop, body and late hue")


func held_prop(model: Node3D) -> String:
	for name: String in Props:
		var node := model.find_child(name, true, false) as MeshInstance3D
		if node != null and node.is_visible_in_tree():
			return name
	return ""
