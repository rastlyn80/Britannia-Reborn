# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Source := "res://local-art/mounts/llama-modern.gltf"
const Clips := {
	4: ["LlamaRearStrike", 0.88], 10: ["LlamaHeadRecoil", 0.47], 25: ["LlamaQuietIdle", 1.12],
	26: ["LlamaForwardCheck", 1.08], 28: ["LlamaPawAlert", 0.72],
}
const LlamaJoints := ["bip01", "bip01 spine1", "bip01 neck1", "bip01 head", "bip01 tail",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 r thigh", "bip01 r calf"]
const WalkJoints := ["bip01 neck1", "bip01 head", "bip01 tail"]


func run() -> void:
	var output := ""
	var pack_model := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="):
			output = argument.trim_prefix("--output-dir=")
		elif argument.begins_with("--pack-model="):
			pack_model = argument.trim_prefix("--pack-model=")
	if not output.is_absolute_path() or (not pack_model.is_empty() and not pack_model.is_absolute_path()):
		fail_bake("pass absolute --output-dir= and optional --pack-model= paths")
		return
	var source := load(Source) as PackedScene
	if source == null:
		fail_bake("prepare and import the ordinary llama scene first")
		return
	var model := source.instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	if rig.get_bone_count() != 29 or not LlamaJoints.all(func(bone: String): return rig.find_bone(bone) >= 0):
		model.free()
		fail_bake("the ordinary llama's original 29-joint rig is required")
		return
	var skin := Ground.skin_points(mesh, rig)
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	for group: int in Clips:
		var descriptor: Array = Clips[group]
		var motion := fit_grounded(player, rig, [skin], descriptor[1], "bip01", LlamaJoints, pose_group.bind(group))
		if group == 25:
			motion.loop_mode = Animation.LOOP_LINEAR
		assert(library.add_animation(descriptor[0], motion) == OK)
	assert(library.add_animation("LlamaCombatWalk", combat_walk(player, rig)) == OK)
	assert(library.add_animation("LlamaRearAndFall", rear_and_fall(player, rig, skin)) == OK)
	verify_base_clips(player, Source)
	var fitted := AnimationLibrary.new()
	var additions := Clips.values().map(func(row: Array): return row[0])
	additions.append_array(["LlamaCombatWalk", "LlamaRearAndFall"])
	for clip: String in additions:
		if fitted.add_animation(clip, library.get_animation(clip)) != OK:
			model.free()
			fail_bake("could not collect fitted motion " + clip)
			return
	model.free()
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		fail_bake("could not create the output directory")
		return
	var library_path := output.path_join("llama-enhanced.res")
	if ResourceSaver.save(fitted, library_path, ResourceSaver.FLAG_COMPRESS) != OK:
		fail_bake("could not save the fitted animation library")
		return
	var manifest := {"schema": 1, "llama-modern.gltf": FileAccess.get_sha256(Source),
		"llama-enhanced.res": FileAccess.get_sha256(library_path)}
	if not pack_model.is_empty():
		var pack_path := output.path_join("pack-llama-modern.scn")
		if not bundle_pack(pack_model, pack_path):
			fail_bake("the original Pack Llama requires its 30-joint rig and two surfaces")
			return
		manifest["pack-llama-modern.scn"] = FileAccess.get_sha256(pack_path)
	var file := FileAccess.open(output.path_join("llama-enhanced.json"), FileAccess.WRITE)
	if file == null:
		fail_bake("could not write the preparation manifest")
		return
	file.store_line(JSON.stringify(manifest, "  ", true))
	print("LLAMA BAKE: 7 fitted motions, original pack ", not pack_model.is_empty())
	quit()


func bundle_pack(path: String, target: String) -> bool:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path, state) != OK:
		return false
	var model := document.generate_scene(state)
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if rigs.size() != 1 or players.size() != 1 or meshes.size() != 1:
		model.free()
		return false
	var rig := rigs[0] as Skeleton3D
	var player := players[0] as AnimationPlayer
	var mesh := meshes[0] as MeshInstance3D
	var scene := PackedScene.new()
	var status := ERR_INVALID_DATA
	var original := ["Idle", "Walk", "Run", "Attack", "Hit", "Death", "Fidget"]
	if rig.get_bone_count() == 30 and rig.find_bone("llamas_pack_load") >= 0 \
			and original.all(player.has_animation) and mesh.mesh.get_surface_count() == 2:
		player.deterministic = true
		status = scene.pack(model)
	model.free()
	return status == OK and ResourceSaver.save(scene, target,
		ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES) == OK


func fail_bake(message: String) -> void:
	printerr("LLAMA BAKE FAIL: ", message)
	quit(1)


func pose_group(rig: Skeleton3D, phase: float, group: int) -> void:
	match group:
		4:
			rear_strike(rig, phase)
		10:
			var recoil := envelope(phase, 0.04, 0.25, 0.55, 0.98)
			turn_world(rig, "bip01 neck1", Vector3.UP, 0.48 * recoil)
			turn_world(rig, "bip01 neck1", Vector3.RIGHT, -0.24 * recoil)
			turn_world(rig, "bip01 head", Vector3.BACK, -0.14 * recoil)
		25:
			turn_world(rig, "bip01 neck1", Vector3.RIGHT, 0.033 * sin(TAU * phase))
			turn_world(rig, "bip01 tail", Vector3.UP, 0.11 * sin(TAU * phase))
		26:
			var reach := envelope(phase, 0.08, 0.49, 0.60, 0.98)
			turn_world(rig, "bip01 neck1", Vector3.RIGHT, 0.93 * reach)
			turn_world(rig, "bip01 head", Vector3.RIGHT, -0.30 * reach)
			turn_world(rig, "bip01 head", Vector3.UP, -0.16 * sin(TAU * phase) * reach)
		28:
			var paw := envelope(phase, 0.02, 0.28, 0.51, 0.92)
			turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.26 * paw)
			turn_world(rig, "bip01 l forearm", Vector3.RIGHT, 0.69 * paw)
			turn_world(rig, "bip01 l hand", Vector3.RIGHT, -0.29 * paw)
			turn_world(rig, "bip01 neck1", Vector3.RIGHT, -0.22 * paw)
			turn_world(rig, "bip01 head", Vector3.UP, 0.13 * paw)


func rear_strike(rig: Skeleton3D, phase: float) -> void:
	var rear := envelope(phase, 0.02, 0.35, 0.51, 0.84)
	var kick := envelope(phase, 0.20, 0.45, 0.58, 0.71)
	var hind := hind_midpoint(rig)
	turn_world(rig, "bip01", Vector3.RIGHT, -0.85 * rear)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.10 * rear)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, 0.27 * rear + 0.14 * kick)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -0.21 * rear)
	for side: String in ["l", "r"]:
		turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -0.34 * rear)
		turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, 0.42 * rear - 0.66 * kick)
		turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, 0.60 * rear)
		turn_world(rig, "bip01 " + side + " calf", Vector3.RIGHT, -0.23 * rear)
	var joint := rig.find_bone("bip01")
	var pose := rig.get_bone_global_pose(joint)
	pose.origin += rig.global_basis.inverse() * (hind - hind_midpoint(rig)).slide(Vector3.UP)
	rig.set_bone_global_pose(joint, pose)


func combat_walk(player: AnimationPlayer, rig: Skeleton3D) -> Animation:
	var source := player.get_animation("Walk")
	var motion := source.duplicate(true) as Animation
	motion.loop_mode = Animation.LOOP_LINEAR
	var path := player.get_node(player.root_node).get_path_to(rig)
	var rotations := {}
	for joint: String in WalkJoints:
		var track_path := NodePath("%s:%s" % [path, joint])
		var track := motion.find_track(track_path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(track, track_path)
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		rotations[track] = rig.find_bone(joint)
	player.play("Walk", 0.0)
	player.advance(0.0)
	for frame in 81:
		var phase := float(frame) / 80.0
		rig.reset_bone_poses()
		player.seek(source.length * phase, true)
		rig.force_update_all_bone_transforms()
		var step := sin(TAU * phase)
		# The source clavicles share the lower neck joint. Bend the upper neck
		# so the combat silhouette changes without carrying the forelegs.
		turn_world(rig, "bip01 neck1", Vector3.RIGHT, 0.66 + 0.036 * step)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.34)
		turn_world(rig, "bip01 tail", Vector3.UP, 0.076 * step)
		for track: int in rotations:
			motion.rotation_track_insert_key(track, source.length * phase, rig.get_bone_pose_rotation(rotations[track]))
	return motion


func rear_and_fall(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary) -> Animation:
	var result := Animation.new()
	result.length = 1.12
	var animation_root := player.get_node(player.root_node)
	var path := animation_root.get_path_to(rig)
	var space := animation_root.find_child("SourceSpace", true, false) as Node3D
	var space_track := result.add_track(Animation.TYPE_POSITION_3D)
	result.track_set_path(space_track, animation_root.get_path_to(space))
	var tracks := []
	for bone in rig.get_bone_count():
		var address := NodePath("%s:%s" % [path, rig.get_bone_name(bone)])
		var channels := []
		for type in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			var track := result.add_track(type)
			result.track_set_path(track, address)
			channels.append(track)
		tracks.append(channels)
	var raised: Array[Transform3D] = []
	sample_source(player, rig, "LlamaRearStrike", 0.37)
	var raised_space := space.position
	for bone in rig.get_bone_count():
		raised.append(rig.get_bone_pose(bone))
	var hip_index := rig.find_bone("bip01")
	for frame in 121:
		var phase := float(frame) / 120.0
		if phase <= 0.29:
			sample_source(player, rig, "LlamaRearStrike", 0.37 * smoothstep(0.0, 0.29, phase))
		else:
			var source_phase := lerpf(0.19, 1.0, (phase - 0.29) / 0.71)
			sample_source(player, rig, "Death", source_phase)
			var weight := smoothstep(0.29, 0.55, phase)
			if weight < 1.0:
				space.position = raised_space.lerp(space.position, weight)
				for bone in rig.get_bone_count():
					rig.set_bone_pose(bone, raised[bone].interpolate_with(rig.get_bone_pose(bone), weight))
		rig.force_update_all_bone_transforms()
		var hip := rig.get_bone_global_pose(hip_index)
		var floor := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		hip.origin += rig.global_basis.inverse() * Vector3.UP * (0.004 - floor)
		rig.set_bone_global_pose(hip_index, hip)
		var time := phase * result.length
		result.position_track_insert_key(space_track, time, space.position)
		for bone in rig.get_bone_count():
			result.position_track_insert_key(tracks[bone][0], time, rig.get_bone_pose_position(bone))
			result.rotation_track_insert_key(tracks[bone][1], time, rig.get_bone_pose_rotation(bone))
			result.scale_track_insert_key(tracks[bone][2], time, rig.get_bone_pose_scale(bone))
	return result


func sample_source(player: AnimationPlayer, rig: Skeleton3D, clip: String, phase: float) -> void:
	if player.assigned_animation != clip:
		player.play(clip, 0.0)
		player.advance(0.0)
	rig.reset_bone_poses()
	player.seek(player.get_animation(clip).length * phase, true)
	rig.force_update_all_bone_transforms()
