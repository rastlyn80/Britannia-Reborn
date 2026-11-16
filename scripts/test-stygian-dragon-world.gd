# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-ordinary-horse-world.gd"

const Profile := preload("res://Presentation/StygianDragonProfile.gd")
const Body := Profile.Body


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	if not expect(Profile.Registry.entry(Body).get("kind") == "stygian_dragon",
			"World startup loads the complete body-826 local profile"):
		return
	var enhanced: bool = world.enhanced_creature_actions
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	var tails: Array[Vector3] = []
	for variant in 2:
		if not await witness(world, at + Vector2i(variant * 3, 0), 0x8260 + variant, variant, enhanced, tails):
			return
	if not expect(tails[0].distance_to(tails[1]) > .3, "The two fitted falls end with different tail poses"):
		return
	print("STYGIAN DRAGON WORLD: ", checks, " checks, Enhanced ", enhanced)
	quit()


func witness(world: Node3D, at: Vector2i, serial: int, variant: int, enhanced: bool, tails: Array[Vector3]) -> bool:
	var packet := mobile_packet(at, serial, Body, 0x40)
	packet[13] = CorpseHue >> 8
	packet[14] = CorpseHue & 255
	world.game._handle(packet)
	var avatar: Node3D = world.avatars[serial]
	var dragon: Node3D = avatar.horse_visual
	if not expect(dragon.kind == "stygian_dragon" and dragon.native_body == Body and dragon.native_hue == CorpseHue
			and dragon.skeleton.get_bone_count() == 57, "The actual avatar keeps body, hue and the original dragon rig"):
		return false
	for group: int in Profile.Classic:
		if group in [2, 3]:
			continue
		world.game._handle(classic(serial, group, 6))
		if not expect(dragon.current_clip == Profile.Classic[group], "Classic group %d selects its fitted movement" % group):
			return false
	if enhanced:
		for sample: Array in [[0, "StygianRake", "StygianLunge"], [5, "StygianRest", "StygianTailCheck"],
				[8, "TakeOff", "TakeOff"], [11, "StygianBreath", "StygianBreath"], [15, "Land", "Land"]]:
			world.game._handle(action_packet(serial, sample[0], variant))
			if not expect(dragon.current_clip == sample[variant + 1], "Enhanced type %d selects its exact tested variant" % sample[0]):
				return false
	world.game._handle(classic(serial, 12, 5))
	if not expect(dragon.current_clip == "StygianBreath" and dragon.action_remaining > 1.3,
			"The stock fire-breath packet keeps its pose through the server windup (%s %.3f %s)" %
			[dragon.current_clip, dragon.action_remaining, dragon.get_meta("native_action", {})]):
		return false
	world.game._handle(classic(serial, 4, 5))
	if not expect(dragon.current_clip == "StygianBreath", "A melee clip cannot replace the active breath"):
		return false
	var death := "Death2" if variant else "Death"
	if enhanced:
		world.game._handle(action_packet(serial, 3, variant))
	else:
		world.game._handle(classic(serial, 2 + variant))
	if not expect(dragon.dead and dragon.current_clip == death, "Both intended death poses resolve"):
		return false
	dragon.animator.advance(0.0)
	dragon.animator.seek(dragon.animator.current_animation_length, true)
	dragon.skeleton.force_update_all_bone_transforms()
	tails.append(dragon.skeleton.get_bone_global_pose(dragon.skeleton.find_bone("bip01 tail2")).origin)
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
	return true


func classic(serial: int, group: int, frames := 5) -> PackedByteArray:
	return PackedByteArray([0x6e]) + Wire.uint_be(serial, 4) + PackedByteArray([0, group, 0, frames, 0, 1, 0, 0, 0])
