# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-ordinary-horse-world.gd"

const Llama := preload("res://Presentation/LlamaActions.gd")
const Pack := 292
const Ethereal := 0x3eab


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	var original_pack := enhanced and "--original-pack" in OS.get_cmdline_user_args()
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	var serial := 0x4201
	var mount_rider := serial + 1
	var pack_serial := serial + 2
	var ethereal_rider := serial + 3
	world.game._handle(mobile_packet(at, serial, Llama.Body, 0))
	world.game._handle(mobile_packet(at, mount_rider, 400, 0))
	world.game._handle(mobile_packet(at, pack_serial, Pack, 0))
	world.game._handle(mobile_packet(at, ethereal_rider, 401, 0))
	world.game._handle(wear_packet(mount_rider, Llama.RidingItem, CorpseHue))
	world.game._handle(wear_packet(ethereal_rider, Ethereal, 0x4001))
	var avatar: Node3D = world.avatars[serial]
	var actor: Node3D = avatar.horse_visual
	var ridden: Node3D = world.avatars[mount_rider].horse_visual
	var pack: Node3D = world.avatars[pack_serial].horse_visual
	var ethereal: Node3D = world.avatars[ethereal_rider].horse_visual
	if not expect(actor.kind == "llama" and ridden.kind == "llama" and (actor.llama_actions != null) == enhanced
			and (ridden.llama_actions != null) == enhanced and ridden.native_hue == CorpseHue
			and ridden.native_mount_item == Llama.RidingItem, "ordinary llama and native worn item use the selected profile"):
		return
	if not expect(pack.native_body == Pack and (pack.pack_fitting != null) == (not original_pack)
			and (pack.llama_actions != null) == original_pack, "pack llama selects the intended load and fall"):
		return
	if original_pack and not expect(pack.original_llama_pack and pack.skeleton.get_bone_count() == 30 and
			pack.skeleton.find_bone("llamas_pack_load") >= 0, "native Pack Llama has its original load joint"):
		return
	if original_pack:
		pack.play_gait(true, 1.8)
		await process_frame
		var animation_time: float = pack.animator.current_animation_position
		await create_timer(.10).timeout
		if not expect(pack.current_clip == "Walk" and pack.animator.current_animation_position > animation_time + .035,
				"the bundled pack animation advances on ordinary client frames"):
			return
	if not expect(ethereal.kind == "llama_ethereal" and ethereal.llama_actions == null
			and ethereal.native_mount_item == Ethereal and ethereal.native_hue == 0x4001,
			"ethereal item retains its own model and spectral dye"):
		return
	if not expect(Mounts.horse_body(0) == 0 and Mounts.BODIES[Pack][1] == 0, "pack body invents no riding item"):
		return
	if not enhanced:
		print("LLAMA WORLD: ", checks, " checks, Enhanced false")
		quit()
		return
	for combat in [false, true]:
		world.game._handle(mobile_packet(at, serial, Llama.Body, 0x40 if combat else 0))
		for movement in [[false, 0.0, "Idle" if combat else Llama.Quiet],
				[true, 1.8, Llama.CombatWalk if combat else "Walk"], [true, 5.5, "Run"]]:
			avatar.animate(movement[0], 0.0, 0.1, movement[1])
			if not expect(actor.current_clip == movement[2], "native mode selects correct gait"):
				return
		for variation in range(6):
			for action in [[0, Llama.Strike], [2, Llama.Quiet if variation % 2 == 0 else "Idle"],
					[4, Llama.Recoil], [5, Llama.Quiet if combat and variation % 2 else Llama.Watch],
					[8, Llama.Alert], [11, Llama.Strike], [14, Llama.Quiet], [15, Llama.Quiet]]:
				world.game._handle(action_packet(serial, action[0], variation))
				if not expect(actor.current_clip == action[1], "decoded Enhanced mode and variation select the reference group"):
					return
		actor.action_remaining = 0.0
	var vortex := mobile_packet(at, serial + 4, Llama.Body, 0x40)
	vortex[14] = 118
	world.game._handle(vortex)
	var rare: Node3D = world.avatars[serial + 4].horse_visual
	world.game._handle(classic_packet(serial + 4, 6))
	if not expect(rare.native_hue == 118 and rare.current_clip == "Attack" and not rare.dead,
			"Energy Vortex llama keeps its Classic group 6 and original dye"):
		return
	for entry in [[-1, "Death"], [0, "Death"], [1, "Death"], [12, "Death2"]]:
		serial += 8
		if not await verify_fall(world, at, serial, entry[0], entry[1]):
			return
	if original_pack:
		for variation in [-1, 0, 1, 12]:
			serial += 8
			if not await verify_fall(world, at, serial, variation, "Death", Pack):
				return
	print("LLAMA WORLD: ", checks, " checks, Enhanced true")
	quit()


func verify_fall(world: Node3D, at: Vector2i, serial: int, variation: int, clip: String, body := Llama.Body) -> bool:
	world.game._handle(mobile_packet(at, serial, body, 0))
	var avatar: Node3D = world.avatars[serial]
	var actor: Node3D = avatar.horse_visual
	if variation == -1:
		avatar.animate(true, 0.0, 0.15, 1.8)
	elif variation == 12:
		world.game._handle(classic_packet(serial, variation))
	else:
		world.game._handle(action_packet(serial, 3, variation))
	if not expect(actor.dead == (variation >= 0) and (variation < 0 or actor.current_clip == clip),
			"decoded fall starts the intended source or fitted clip"):
		return false
	actor.animator.advance(0.0)
	actor.animator.seek(0.27 * actor.animator.current_animation_length, true)
	var before := joint_positions(actor)
	var corpse := 0x4002f000 + serial
	if variation % 2 == 0:
		world.game._handle(corpse_packet(at, corpse, body, 0))
	world.game._handle(death_packet(serial, corpse))
	if variation % 2 != 0:
		world.game._handle(corpse_packet(at, corpse, body, 0))
	var active: Dictionary = world.creature_deaths.active.get(serial, {})
	var holder: Node3D = world.world_items.nodes[corpse]
	if not expect(not active.is_empty() and not holder.visible and active.visual.current_clip == clip,
			"normal World continues the intended fall for either corpse packet order"):
		return false
	var after := joint_positions(active.visual)
	var displacement := 0.0
	for joint in before.size():
		displacement = maxf(displacement, before[joint].distance_to(after[joint]))
	if not expect(displacement < 0.003, "fall preserves the previous pose, max joint shift %.5f m" % displacement):
		return false
	await create_timer(float(active.remaining) + 0.16).timeout
	var frozen: Node3D = holder.get_node("CorpseVisual")
	if not expect(holder.visible and frozen.get_meta("death_clip") == clip and frozen.find_children("*", "Skeleton3D").is_empty(),
			"0x2006 item freezes the fall"):
		return false
	var placement := frozen.global_transform
	var bounds: AABB = frozen.get_meta("corpse_bounds")
	var frozen_parts := surfaces(frozen)
	if body == Pack and not expect(frozen_parts.values().any(func(counts: Array): return counts.size() == 2),
			"the pack surface is retained on the static native corpse"):
		return false
	world.game._handle(corpse_packet(at, corpse, body, CorpseHue))
	var dyed: Node3D = world.world_items.nodes[corpse].get_node("CorpseVisual")
	if not dyed.global_transform.is_equal_approx(placement):
		print("Llama corpse after dye, variant ", variation, " before ", frozen_parts, " after ", surfaces(dyed),
			", stored snapshot ", world.world_items.corpse_snapshots.has(corpse))
	return expect(dyed.get_meta("death_clip") == clip and dyed.get_meta("native_hue") == CorpseHue \
		and dyed.global_transform.is_equal_approx(placement) and dyed.get_meta("corpse_bounds") == bounds,
		"late corpse dye preserves the selected pose and placement")


func surfaces(visual: Node3D) -> Dictionary:
	var parts := {}
	for mesh: MeshInstance3D in visual.get_children():
		var counts := []
		for index in mesh.mesh.get_surface_count():
			counts.append(mesh.mesh.surface_get_array_len(index))
		parts[mesh.name] = counts
	return parts


func joint_positions(actor: Node3D) -> PackedVector3Array:
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	var result := PackedVector3Array()
	for index in rig.get_bone_count():
		result.append(rig.to_global(rig.get_bone_global_pose(index).origin))
	return result


func classic_packet(serial: int, action: int) -> PackedByteArray:
	var bytes := PackedByteArray([0x6e])
	bytes.append_array(Wire.uint_be(serial, 4))
	bytes.append_array(Wire.uint_be(action, 2))
	bytes.append_array(Wire.uint_be(8, 2))
	bytes.append_array(Wire.uint_be(1, 2))
	bytes.append_array(PackedByteArray([1, 0, 0]))
	return bytes
