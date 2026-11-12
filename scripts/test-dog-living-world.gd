# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Visual := preload("res://Presentation/SourceLivingCougarVisual.gd")
const Body := 217
const Selectors := [[2, 0, "HoundRearBark"], [5, 0, "HoundScentCheck"], [5, 1, "HoundTailCheck"],
	[8, 0, "HoundAlert"], [11, 0, "HoundBowSnap"], [14, 0, "HoundQuietStand"], [15, 0, "HoundQuietStand"]]


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
	var serial := 0x6200
	for alternate in [false, true]:
		world.game._handle(mobile_packet(at, serial, Body, 0x40))
		var avatar: Node3D = world.avatars[serial]
		var visual := avatar.horse_visual as Visual
		if not expect(visual != null and visual.native_body == Body and visual.tail.size() >= 3
				and visual.contact.feet.size() == 4, "World selects the original Dog rig and all limb chains"):
			return
		world.game._handle(classic_packet(serial, 10 if alternate else 9))
		if not expect(visual.current_clip == ("Fidget2" if alternate else "Fidget"),
				"the distinct hound's Classic gestures remain mapped"):
			return
		avatar.animate(true, 0.0, .16, 5.5)
		if not expect(visual.current_clip == "Run", "movement interrupts the idle gesture"):
			return
		if enhanced:
			for request: Array in Selectors:
				world.game._handle(action_packet(serial, request[0], request[1]))
				if not expect(visual.current_clip == request[2], "the exact Enhanced motion plays"):
					return
		else:
			world.game._handle(classic_packet(serial, 4))
			if not expect(visual.current_clip == "Fidget", "Classic Alert retains its Fidget"):
				return
		var expected := "Death2" if alternate else "Death"
		if alternate:
			world.game._handle(classic_packet(serial, 12))
		visual.animator.advance(0.0)
		visual.animator.seek(.28 * visual.animator.current_animation_length, true)
		if not await check_corpse(world, at, serial, expected, alternate):
			return
		serial += 1
	print("DOG LIVING WORLD: ", checks, " checks, Enhanced ", enhanced)
	world.queue_free()
	await process_frame
	quit()


func check_corpse(world: Node3D, at: Vector2i, serial: int, expected: String, alternate: bool) -> bool:
	var corpse := 0x40003100 + serial
	if alternate:
		world.game._handle(corpse_packet(at, corpse, Body, 0))
	world.game._handle(death_packet(serial, corpse))
	if not alternate:
		world.game._handle(corpse_packet(at, corpse, Body, 0))
	var transition: Dictionary = world.creature_deaths.active.get(serial, {})
	if not expect(not transition.is_empty() and transition.visual.native_body == Body
			and transition.visual.current_clip == expected, "the server's Dog corpse continues its selected fall"):
		return false
	await create_timer(float(transition.remaining) + .12).timeout
	var item: Node3D = world.world_items.nodes[corpse]
	var prior: Node3D = item.get_node("CorpseVisual")
	var placement := prior.global_transform
	var bounds: AABB = prior.get_meta("corpse_bounds")
	world.game._handle(corpse_packet(at, corpse, Body, CorpseHue))
	item = world.world_items.nodes[corpse]
	var frozen: Node3D = item.get_node("CorpseVisual")
	return expect(item.visible and frozen.get_meta("corpse_body") == Body and frozen.get_meta("death_clip") == expected
			and frozen.get_meta("native_hue") == CorpseHue and frozen.global_transform.is_equal_approx(placement)
			and frozen.get_meta("corpse_bounds") == bounds, "later dye preserves the frozen Dog geometry")
