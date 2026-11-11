# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-bovine-actions.gd"
## Additional measured poses on the retained Third Dawn cattle rigs.

const Bodies := {216: "bovine_cow_spotted", 231: "bovine_cow_brown", 232: "bovine_bull_brown", 233: "bovine_bull_spotted"}
const Fits := {2: "BovineEnhancedFall", 10: "BovineHeadRecoil", 15: "BovineShortNudge",
	25: "BovineGrazingIdle", 26: "BovineGrazeTailFlick", 28: "BovineGrazeAlert"}
const Frames := {2: 13, 10: 6, 15: 8, 25: 11, 26: 9, 28: 7}


func _initialize() -> void:
	create_timer(180.).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	var output := ProjectSettings.globalize_path("res://../work/creatures/enhanced-cattle-bake")
	DirAccess.make_dir_recursive_absolute(output)
	var variants := ["modern"] if "--modern-only" in OS.get_cmdline_user_args() else ["original", "rounded", "modern"]
	for body: int in Bodies:
		for treatment: String in variants:
			fit_body(body, treatment, output)
	var receipt := FileAccess.open(output.path_join("candidate-poses.json"), FileAccess.WRITE)
	receipt.store_string(JSON.stringify(baked, "  "))
	print("ENHANCED CATTLE BAKE: ", baked.size(), " scenes")
	quit()


func fit_body(body: int, treatment: String, output: String) -> void:
	var path := "res://local-art/animals/%s-%s-actions.scn" % [Bodies[body], treatment]
	var model := (load(path) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var reports := {}
	for group: int in Fits:
		var result := fit_source_action(player, rig, skin, body, group)
		assert(player.get_animation_library("").add_animation(Fits[group], result.clip) == OK)
		reports[Fits[group]] = result.evidence
	player.stop()
	var saved := PackedScene.new()
	var target := output.path_join("%d-%s.scn" % [body, treatment])
	assert(saved.pack(model) == OK and ResourceSaver.save(saved, target, ResourceSaver.FLAG_COMPRESS) == OK)
	baked[target.get_file()] = {"source": FileAccess.get_sha256(path), "scene": FileAccess.get_sha256(target), "poses": reports}
	model.free()


func fit_source_action(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, body: int, group: int) -> Dictionary:
	var source := player.get_animation("Idle")
	var clip := source.duplicate(true) as Animation
	var count: int = (11 if group == 2 else 10) if body == 232 and group in [2, 25] else Frames[group]
	clip.length = float(count) * .1
	clip.loop_mode = Animation.LOOP_LINEAR if group == 25 else Animation.LOOP_NONE
	var root_bone := rig.find_bone("bip01")
	var animation_root := player.get_node(player.root_node)
	var position_path := NodePath(str(animation_root.get_path_to(rig)) + ":bip01")
	var position_track := clip.find_track(position_path, Animation.TYPE_POSITION_3D)
	var rotations := {}
	for track in clip.get_track_count():
		var bone := rig.find_bone(str(clip.track_get_path(track).get_concatenated_subnames()))
		for key in range(clip.track_get_key_count(track) - 1, 0, -1):
			clip.track_remove_key(track, key)
		if bone >= root_bone and clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			rotations[bone] = track
	if position_track < 0:
		position_track = clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(position_track, position_path)
	var head := rig.find_bone("bip01 head")
	assert(root_bone >= 0 and head >= 0)
	player.play("Idle", 0.)
	player.advance(0.)
	var head_path := []
	var minimum_gap := INF
	for frame in 81:
		var phase := float(frame) / 80.
		rig.reset_bone_poses()
		player.seek(0., true)
		rig.force_update_all_bone_transforms()
		pose_cattle(rig, body, group, phase)
		var hip := rig.get_bone_global_pose(root_bone)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		hip.origin += rig.global_basis.inverse() * Vector3.UP * (.003 - gap)
		rig.set_bone_global_pose(root_bone, hip)
		rig.force_update_all_bone_transforms()
		var clearance := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		assert(is_finite(clearance) and absf(clearance - .003) < .0001)
		minimum_gap = minf(minimum_gap, clearance)
		var time := phase * clip.length
		clip.position_track_insert_key(position_track, time, rig.get_bone_pose_position(root_bone))
		for bone: int in rotations:
			clip.rotation_track_insert_key(rotations[bone], time, rig.get_bone_pose_rotation(bone))
		if frame % 20 == 0:
			var spot := rig.to_global(rig.get_bone_global_pose(head).origin)
			head_path.append([spot.x, spot.y, spot.z])
	return {"clip": clip, "evidence": {"minimum_gap": minimum_gap, "head_path": head_path, "poses": 81}}


func pose_cattle(rig: Skeleton3D, body: int, group: int, phase: float) -> void:
	if group == 2:
		var brace := smoothstep(0., .15, phase) * (1. - smoothstep(.20, .62, phase))
		var drop := smoothstep(.28, .88, phase)
		var roll := 2.60 if body == 232 else 1.48 if body == 233 else 1.37
		turn_world(rig, "bip01", Vector3.FORWARD, roll * drop)
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.14 * brace + .18 * drop)
		turn_world(rig, "bip01 neck", Vector3.RIGHT, -.26 * brace + .38 * drop)
		turn_world(rig, "bip01 neck2", Vector3.RIGHT, -.19 * brace - .17 * drop)
		turn_world(rig, "bip01 tail1", Vector3.UP, .41 * drop)
		for side: String in ["l", "r"]:
			var offset := 1. if side == "l" else .88
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -.49 * drop * offset)
			turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, .93 * drop * offset)
			turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, -.51 * drop * offset)
			turn_world(rig, "bip01 " + side + " calf", Vector3.RIGHT, .78 * drop * offset)
		return
	var pulse := pow(sin(PI * phase), 2.)
	if group == 10:
		turn_world(rig, "bip01 neck1", Vector3.RIGHT, -.50 * (1. - smoothstep(.34, .98, phase)))
		turn_world(rig, "bip01 head", Vector3.UP, .24 * pulse)
		turn_world(rig, "bip01 tail1", Vector3.UP, .22 * sin(TAU * phase))
		return
	if group == 15:
		turn_world(rig, "bip01 neck1", Vector3.RIGHT, .28 * pulse)
		turn_world(rig, "bip01 neck2", Vector3.RIGHT, -.21 * pulse)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -.24 * pulse)
		turn_world(rig, "bip01 l forearm", Vector3.RIGHT, .30 * pulse)
		return
	var graze := (1. - smoothstep(.18, .69, phase)) if group == 28 else 1.
	# Both clavicles hang from neck. Articulate the lower neck below
	# their branch so a standing animal's forehooves stay planted.
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .62 * graze + .042 * pulse)
	turn_world(rig, "bip01 neck2", Vector3.RIGHT, .29 * graze)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.17 * graze)
	if group == 26:
		turn_world(rig, "bip01 tail1", Vector3.UP, .62 * pulse * sin(TAU * phase))
