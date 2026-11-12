# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Visual := preload("res://Presentation/SourceLivingCatVisual.gd")
const Body := 201
const Selectors := [[2, 0, "CatTailRecoil"], [5, 0, "CatListening"], [5, 1, "CatRearAndSwipe"],
	[8, 0, "CatStartle"], [11, 0, "CatSpring"], [14, 0, "CatQuietStand"], [15, 0, "CatQuietStand"]]


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
	for index in 2:
		var serial := 0x6300 + index
		var hue := 0x650 if index else 2305
		var mobile := mobile_packet(at, serial, Body, 0x40)
		mobile[13] = hue >> 8
		mobile[14] = hue & 0xff
		world.game._handle(mobile)
		var avatar: Node3D = world.avatars[serial]
		var visual := avatar.horse_visual as Visual
		if not expect(visual != null and visual.native_body == Body and visual.native_hue == hue
				and visual.contact.feet.size() == 4 and visual.contact.stride == 8,
				"World selects the Cat rig with all four eight-influence paws and the native coat"):
			return
		world.game._handle(classic_packet(serial, 9 if index else 10))
		if not expect(visual.current_clip == ("CatStretch" if index else "Fidget2"),
				"Both Classic cat gestures keep their original action numbers"):
			return
		avatar.animate(true, 0.0, .16, 1.8)
		if not expect(visual.current_clip == "Run", "movement releases an idle cat gesture"):
			return
		if enhanced:
			for request: Array in Selectors:
				world.game._handle(action_packet(serial, request[0], request[1]))
				if not expect(visual.current_clip == request[2], "the exact Enhanced selector plays"):
					return
		if index:
			var breath := classic_packet(serial, 12)
			breath[8] = 5
			breath[11] = 0
			world.game._handle(breath)
			if not expect(visual.current_clip == "Alert" and not visual.dead,
					"the exact stock Hell Cat breath signature stays upright"):
				return
			world.game._handle(classic_packet(serial, 8))
		visual.animator.advance(0.0)
		visual.animator.seek(.28 * visual.animator.current_animation_length, true)
		if not await check_corpse(world, at, serial, "Death2" if index else "Death", index != 0, hue):
			return
	print("CAT LIVING WORLD: ", checks, " checks, Enhanced ", enhanced)
	world.queue_free()
	await process_frame
	quit()


func check_corpse(world: Node3D, at: Vector2i, serial: int, expected: String, alternate: bool, hue: int) -> bool:
	var corpse := 0x40003100 + serial
	if alternate:
		world.game._handle(corpse_packet(at, corpse, Body, hue))
	world.game._handle(death_packet(serial, corpse))
	if not alternate:
		world.game._handle(corpse_packet(at, corpse, Body, hue))
	var transition: Dictionary = world.creature_deaths.active.get(serial, {})
	if not expect(not transition.is_empty() and transition.visual.native_body == Body
			and transition.visual.current_clip == expected, "native corpse continues its selected Cat fall"):
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
			and frozen.get_meta("corpse_bounds") == bounds, "later dye preserves the frozen Cat geometry")
