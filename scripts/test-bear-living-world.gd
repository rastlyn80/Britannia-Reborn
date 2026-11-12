# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Visual := preload("res://Presentation/SourceLivingBearVisual.gd")
const Forms := {211: "BlackBear", 167: "BrownBear"}
const Selectors := [[2, 0, "UprightWarning"], [5, 0, "ScentTurn"], [5, 1, "RaisedGuard"],
	[8, 0, "RearAlert"], [11, 0, "HighSwipe"], [14, 0, "QuietStand"], [15, 0, "WakeAndRise"]]


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
	var serial := 0x6100
	for body: int in Forms:
		for alternate in [false, true]:
			world.game._handle(mobile_packet(at, serial, body, 0x40))
			var avatar: Node3D = world.avatars[serial]
			var visual := avatar.horse_visual as Visual
			if not expect(visual != null and visual.native_body == body and visual.contact.feet.size() == 4,
					"World selects this native bear and all four original paw chains"):
				return
			world.game._handle(classic_packet(serial, 10 if alternate else 9))
			if not expect(visual.current_clip == ("Fidget2" if alternate else "Fidget"),
					"the distinct Classic fidgets remain mapped"):
				return
			avatar.animate(true, 0.0, .16, 5.5)
			if not expect(visual.current_clip == "Run", "movement interrupts the fidget"):
				return
			if enhanced:
				for request: Array in Selectors:
					world.game._handle(action_packet(serial, request[0], request[1]))
					if not expect(visual.current_clip == Forms[body] + request[2],
							"the exact Enhanced clip is retained"):
						return
			else:
				world.game._handle(classic_packet(serial, 7))
				if not expect(visual.current_clip == "Hit", "the native Classic recoil is retained"):
					return
			if not await check_corpse(world, at, serial, body, alternate):
				return
			serial += 1
	print("BEAR LIVING WORLD: ", checks, " checks, Enhanced ", enhanced)
	world.queue_free()
	await process_frame
	quit()


func check_corpse(world: Node3D, at: Vector2i, serial: int, body: int, alternate: bool) -> bool:
	var corpse := 0x40003100 + serial
	if alternate:
		world.game._handle(corpse_packet(at, corpse, body, 0))
	world.game._handle(death_packet(serial, corpse))
	if not alternate:
		world.game._handle(corpse_packet(at, corpse, body, 0))
	var transition: Dictionary = world.creature_deaths.active.get(serial, {})
	if not expect(not transition.is_empty() and transition.visual.native_body == body,
			"the client starts a death transition for the server's bear body"):
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
			and frozen.global_transform.is_equal_approx(placement) and frozen.get_meta("corpse_bounds") == bounds,
			"the frozen bear retains its exact geometry and takes the later server dye")
