# SPDX-License-Identifier: GPL-3.0-or-later
extends "test-forgotten-servant-world.gd"

const Body := 264
const Travesty := 0x2356


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var at := Vector2i(int(world.world.originX) + 5, int(world.world.originY) + 5)
	update_body(world, at, Body, 0)
	var av: Node3D = world.avatars[Travesty]
	if not expect(av.horse_visual != null and av.horse_visual.native_body == Body,
			"Travesty's original body selects the Changeling creature mesh"):
		return
	var original: Node3D = av.horse_visual
	update_body(world, at, 401, 0x83ea)
	world.game._handle(item_packet(Travesty, 11, 0x203c, 1147))
	world.game._handle(item_packet(Travesty, 5, 0x1efd, 1309))
	var human: Node3D = world.avatars[Travesty].human_visual
	if not expect(human != null and human.female and human.skin_hue == 0x83ea,
			"The same server serial changes to the female rig and receives the exact skin hue"):
		return
	if not expect(human.native_cosmetics.hair_id == 0x203c and human.native_cosmetics.hair_hue == 1147
			and garment(human, "/shirt.glb") != null, "The disguise keeps its dyed hair and shirt"):
		return
	var remove_shirt := PackedByteArray([0x1d])
	remove_shirt.append_array(Wire.uint_be(item_serial(Travesty, 5), 4))
	world.game._handle(remove_shirt)
	update_body(world, at, Body, 0)
	av = world.avatars[Travesty]
	if not expect(av.human_visual == null and av.horse_visual != null and av.horse_visual != original,
			"The original body reinstates the creature rig"):
		return
	var corpse := 0x40000000 + Travesty
	world.game._handle(corpse_packet(at, corpse, Body, 0))
	world.game._handle(death_packet(Travesty, corpse))
	var state: Dictionary = world.creature_deaths.active.get(Travesty, {})
	if not expect(not state.is_empty() and state.visual.native_body == Body,
			"The normal death packet selects the Changeling collapse"):
		return
	await create_timer(float(state.remaining) + .12).timeout
	var frozen: Node3D = world.world_items.nodes[corpse].get_node_or_null("CorpseVisual")
	if not expect(frozen != null and frozen.get_meta("corpse_body") == Body and frozen.get_meta("static_cadaver")
			and frozen.find_children("*", "Skeleton3D", true, false).is_empty(), "The native corpse is frozen in the Changeling shape"):
		return
	print("TRAVESTY WORLD: ", checks, " checks, Enhanced ", world.enhanced_creature_actions)
	quit(0)


func update_body(world: Node, at: Vector2i, body: int, hue: int) -> void:
	var packet := mobile_packet(at, Travesty, body, 0)
	packet[13] = hue >> 8
	packet[14] = hue & 255
	world.game._handle(packet)
