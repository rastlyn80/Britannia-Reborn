# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-ordinary-horse-world.gd"

const Profile := preload("res://Presentation/SlasherProfile.gd")
const Body := Profile.Body


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	if not expect(Profile.Registry.entry(Body).get("kind") == "slasher_of_veils",
			"World startup loads the complete body-741 local profile"):
		return
	var enhanced: bool = world.enhanced_creature_actions
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	for variant in 2:
		if not await witness(world, at + Vector2i(variant * 3, 0), 0x7410 + variant, variant, enhanced):
			return
	print("SLASHER WORLD: ", checks, " checks, Enhanced ", enhanced)
	quit()


func witness(world: Node3D, at: Vector2i, serial: int, variant: int, enhanced: bool) -> bool:
	var packet := mobile_packet(at, serial, Body, 0x40)
	packet[13] = CorpseHue >> 8
	packet[14] = CorpseHue & 255
	world.game._handle(packet)
	var avatar: Node3D = world.avatars[serial]
	var slasher: Node3D = avatar.horse_visual
	if not expect(slasher.kind == "slasher_of_veils" and slasher.native_body == Body and slasher.native_hue == CorpseHue
			and slasher.skeleton.get_bone_count() == 75, "The actual avatar keeps body, hue and the fitted Third Dawn rig"):
		return false
	for group: int in Profile.Classic:
		if group in [2, 3]:
			continue
		world.game._handle(classic(serial, group))
		if not expect(slasher.current_clip == Profile.Classic[group], "Classic group %d selects its fitted movement" % group):
			return false
	if enhanced:
		for sample: Array in [[0, "SlasherRake", "SlasherDoubleClaw"], [5, "SlasherSurvey", "SlasherFire"],
				[8, "SlasherGuard", "SlasherGuard"], [11, "SlasherFear", "SlasherFear"], [15, "SlasherVeil", "SlasherVeil"]]:
			world.game._handle(action_packet(serial, sample[0], variant))
			if not expect(slasher.current_clip == sample[variant + 1], "Enhanced type %d selects its exact tested variant" % sample[0]):
				return false
	var death := "Death2" if variant else "Death"
	if enhanced:
		world.game._handle(action_packet(serial, 3, variant))
	else:
		world.game._handle(classic(serial, 2 + variant))
	if not expect(slasher.dead and slasher.current_clip == death, "Both intended death poses resolve"):
		return false
	var corpse := 0x40000000 + serial
	if variant == 0:
		world.game._handle(corpse_packet(at, corpse, Body, CorpseHue))
		world.game._handle(death_packet(serial, corpse))
	else:
		world.game._handle(death_packet(serial, corpse))
		world.game._handle(corpse_packet(at, corpse, Body, CorpseHue))
	var item: Node3D = world.world_items.nodes[corpse]
	var state: Dictionary = world.creature_deaths.active.get(serial, {})
	if not expect(not state.is_empty() and not item.visible, "The existing or late corpse waits for the live fall"):
		return false
	await create_timer(float(state.remaining) + .20).timeout
	var frozen := item.get_node_or_null("CorpseVisual") as Node3D
	if not expect(frozen != null and item.visible and frozen.get_meta("death_clip", "") == death
			and frozen.get_meta("native_hue") == CorpseHue and frozen.find_children("*", "Skeleton3D", true, false).is_empty(),
			"The server's corpse is visible, frozen, dyed and uses the same fall"):
		return false
	if not expect(frozen.get_meta("vertices", 0) == 21385 and frozen.get_child(0).mesh.get_surface_count() == 2,
			"The frozen corpse includes the body, claws and mantle"):
		return false
	return true


func classic(serial: int, group: int) -> PackedByteArray:
	return PackedByteArray([0x6e]) + Wire.uint_be(serial, 4) + PackedByteArray([0, group, 0, 5, 0, 1, 1, 0, 0])
