# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-frost-through-gargoyle-actions.gd"

const Profile := preload("res://Presentation/EnhancedCreatureActions.gd")
const Installed := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Old := preload("res://Presentation/NativeMobileActions.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const Path := "res://../work/creatures/native-form-audit/enhanced-source-gaps/amou/"
const Names := {17: ["OrcRise", "OrcAlert"], 16: ["WaterEmerge", "WaterAlert"]}

class RouteAvatar extends Node3D:
	var horse_visual: Node3D
	func receive_native_action(request: Dictionary) -> bool:
		return horse_visual.receive_action(request)

func run() -> void:
	var index := "res://local-art/creatures/accepted-index.json"
	var digest := FileAccess.get_sha256(index)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var routes := 0
	var compatible := 0
	var metrics := {}
	var hashes := {}
	var installed := "--installed" in OS.get_cmdline_user_args()
	var baseline := {17: Registry.entry(17), 16: Registry.entry(16)}
	if installed:
		assert(Installed.enable())
	for body: int in Names:
		var base: Dictionary = baseline[body]
		var trial := Registry.entry(body) if installed else base.duplicate(true)
		var expected := {"0": {"15": [Names[body][0]], "8": [Names[body][1]]}, "1": {}}
		if installed:
			assert(trial.enhanced_source_action_groups == expected)
		else:
			trial["enhanced_source_action_groups"] = expected
		hashes[str(body)] = {}
		for treatment: String in trial.assets:
			if not installed:
				trial.assets[treatment] = Path + ("%s-%s.scn" % ["orc" if body == 17 else "water", treatment])
			hashes[str(body)][treatment] = FileAccess.get_sha256(trial.assets[treatment])
		Registry.entries[body] = trial
		game.entities[body] = {"serial": body, "body": body, "hue": 53}
		for treatment: String in trial.assets:
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body, 53)
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.contact.active = false
			Exact.check_earlier_keys(actor.animator, Registry.asset_path(base, treatment))
			var avatar := RouteAvatar.new()
			avatar.horse_visual = actor
			for selection: Array in [[15, Names[body][0]], [8, Names[body][1]]]:
				for flags: int in [0, 0x40]:
					for variation: int in [0, 1, 127]:
						var packet: Dictionary = NewPacket.decode_new(game, body, selection[0], 0, variation)
						assert(Profile.dispatch(avatar, packet, true, flags))
						assert(actor.current_clip == selection[1] and not actor.dead and actor.action_remaining > .0)
						assert(actor.entry == trial)
						routes += 1
					for variation: int in [0, 128, 255]:
						var packet: Dictionary = NewPacket.decode_new(game, body, selection[0], 0, variation)
						var accepted := Old.dispatch(avatar, packet)
						var clip: String = actor.current_clip
						assert(Profile.dispatch(avatar, packet, variation >= 128, flags) == accepted)
						assert(actor.current_clip == clip)
						compatible += 1
			metrics["%s-%s" % [body, treatment]] = measure(actor, body)
			if body == 16:
				metrics["water_morph"] = measure_water_morph(actor)
			avatar.free()
			actor.free()
		for hue: int in [0, 53, 0x8035]:
			var cadaver := Corpses.build(body, hue)
			assert(cadaver.get_meta("corpse_body") == body and cadaver.get_meta("native_hue") == hue)
			assert(cadaver.get_meta("static_cadaver") and cadaver.get_meta("death_clip") == "Death")
			assert(cadaver.find_children("*", "AnimationPlayer", true, false).is_empty())
			cadaver.free()
			static_corpses += 1
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		var orc := Registry.entry(17)
		var measured := orc.duplicate(true)
		measured["archive_grounded_gestures"] = Names[17]
		Registry.entries[17] = measured
		for treatment: String in orc.assets:
			sample_ranked_ground(plane, 17, treatment)
		Registry.entries[17] = orc
		plane.free()
		await physics_frame
	assert(routes == 48 and compatible == 48 and static_corpses == 6)
	assert(ground_poses == SLOPES.size() * 3 * 2 * 31 and lowest > .0004)
	assert(FileAccess.get_sha256(index) == digest)
	game.free()
	if not installed:
		var file := FileAccess.open(Path + "ranked-enhanced-candidate.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"routes": routes, "classic_compatibility": compatible,
			"corpse_hues": static_corpses, "orc_terrain_poses": ground_poses, "orc_terrain_minimum": lowest,
			"motion": metrics, "scene_sha256": hashes,
			"test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	print("RANKED ENHANCED: ", routes, " selections, ", compatible, " preserving checks, ",
		ground_poses, " Orc terrain poses, ", static_corpses, " static corpse hues")
	print(metrics)
	quit()

func measure(actor: Node3D, body: int) -> Dictionary:
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var measure_head := "bip01 head" if body == 17 else "Head"
	var measure_hand := "bip01 l hand" if body == 17 else "hand_l"
	var result := {}
	for clip: String in Names[body]:
		player.stop()
		player.play(clip, 0.0)
		player.advance(0.0)
		var first := Vector3.ZERO
		var final := Vector3.ZERO
		var joint := rig.find_bone(measure_head if clip == Names[body][0] else measure_hand)
		for sample: int in [0, 1]:
			player.seek(player.current_animation_length * sample, true)
			rig.force_update_all_bone_transforms()
			var position := rig.to_global(rig.get_bone_global_pose(joint).origin)
			if sample == 0:
				first = position
			else:
				final = position
		assert(final.y - first.y > (.50 if clip == Names[body][0] else .09), str([body, clip, first, final]))
		result[clip] = final.y - first.y
	return result

func measure_water_morph(actor: Node3D) -> Dictionary:
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var fluid := actor.model.find_child("FluidBody", true, false) as MeshInstance3D
	var slot := fluid.find_blend_shape_by_name("FormationSpire")
	assert(slot >= 0)
	var shape: Array = fluid.mesh.surface_get_blend_shape_arrays(0)[slot]
	var target: PackedVector3Array = shape[Mesh.ARRAY_VERTEX]
	var source: PackedVector3Array = fluid.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert(target.size() == source.size() and target != source)
	var skin := Ground.skin_points(fluid, rig)
	var primary: Dictionary = skin.surfaces[0]
	var arrays := fluid.mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var min_y := INF
	player.stop()
	player.play("WaterEmerge", 0.0)
	player.advance(0.0)
	assert(is_equal_approx(fluid.get_blend_shape_value(slot), 1.0))
	for i in 31:
		player.seek(float(i) / 30.0 * player.current_animation_length, true)
		rig.force_update_all_bone_transforms()
		var influence := fluid.get_blend_shape_value(slot)
		var matrices: Array[Transform3D] = []
		for bind in skin.bones.size():
			matrices.append(rig.get_bone_global_pose(skin.bones[bind]) * skin.bind_poses[bind])
		for vertex in source.size():
			var point := Vector3.ZERO
			var p := source[vertex].lerp(target[vertex], influence)
			for offset in primary.stride:
				var index: int = vertex * primary.stride + offset
				if weights[index] > 0.0:
					point += matrices[indices[index]] * p * weights[index]
			min_y = minf(min_y, rig.to_global(point).y)
	assert(min_y >= -.002 and is_zero_approx(fluid.get_blend_shape_value(slot)), str(min_y))
	for clip: String in ["Idle", "Attack", "Death"]:
		player.stop()
		player.play("WaterEmerge", 0.0)
		player.advance(0.0)
		player.seek(.12, true)
		assert(fluid.get_blend_shape_value(slot) > .75)
		player.play(clip, .12)
		player.advance(.13)
		assert(is_zero_approx(fluid.get_blend_shape_value(slot)), clip)
	return {"minimum_flat_clearance": min_y, "interrupted_transitions": 3, "samples": 31}
