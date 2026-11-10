# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-chicken-distinct-actions.gd"

const ChickenStage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/chicken-skeletal-mage/"
const ChickenSourceSHA := "bd8d4c657eff1afefb78e3815cf051930439a8c3572bc422b9e93f239c4a045a"
const ChickenClips := {4: "ChickenQuickPeck", 25: "ChickenSettledWatch", 28: "ChickenLowAlert"}
const ChickenLengths := {4: .57, 25: .88, 28: .62}

func run() -> void:
	assert(FileAccess.get_sha256(INPUT) == ChickenSourceSHA)
	var model := (load(INPUT) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var owner := player.get_node(player.root_node)
	var motion := owner.get_node("AuthoredChickenMotion") as Node3D
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var roots: Array[String] = []
	for bone in rig.get_bone_count():
		if rig.get_bone_parent(bone) < 0:
			roots.append(rig.get_bone_name(bone))
	assert(roots.size() == 8 and meshes.size() == 2)
	for group: int in ChickenClips:
		var fitted := fit_gesture(player, rig, motion, roots, meshes, group)
		assert(library.add_animation(ChickenClips[group], fitted) == OK)
	player.stop()
	rig.reset_bone_poses()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, ChickenStage + "208-modern.scn", ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("CHICKEN ENHANCED: three source-fitted motions on the bundled CC0 rig")
	quit()

func fit_gesture(player: AnimationPlayer, rig: Skeleton3D, motion: Node3D,
		roots: Array[String], meshes: Array, group: int) -> Animation:
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	clip.length = ChickenLengths[group]
	clip.loop_mode = Animation.LOOP_NONE
	for track in clip.get_track_count():
		for key in range(clip.track_get_key_count(track) - 1, 0, -1):
			clip.track_remove_key(track, key)
	var paths := player.get_node(player.root_node).get_path_to(rig)
	var rotation := {}
	var translation := {}
	for name: String in roots + ["Leg_L.001", "Leg_R.001", "Leg_L.002", "Leg_R.002", "Head", "Bone.006"]:
		rotation[name] = reserve(clip, NodePath("%s:%s" % [paths, name]), Animation.TYPE_ROTATION_3D)
	for name: String in roots:
		translation[name] = reserve(clip, NodePath("%s:%s" % [paths, name]), Animation.TYPE_POSITION_3D)
	var motion_track := reserve(clip, ^"AuthoredChickenMotion", Animation.TYPE_POSITION_3D)
	player.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 81:
		var phase := float(frame) / 80.0
		rig.reset_bone_poses()
		player.seek(0.0, true)
		motion.position = Vector3.ZERO
		rig.force_update_all_bone_transforms()
		pose_gesture(rig, motion, roots, phase, group)
		motion.position.y += .003 - bounds(meshes, rig).position.y
		var time := phase * clip.length
		for name: String in rotation:
			clip.rotation_track_insert_key(rotation[name], time, rig.get_bone_pose_rotation(rig.find_bone(name)))
		for name: String in translation:
			clip.position_track_insert_key(translation[name], time, rig.get_bone_pose_position(rig.find_bone(name)))
		clip.position_track_insert_key(motion_track, time, motion.position)
	return clip

func reserve(clip: Animation, path: NodePath, type: Animation.TrackType) -> int:
	var track := clip.find_track(path, type)
	if track < 0:
		track = clip.add_track(type)
		clip.track_set_path(track, path)
	clear_keys(clip, track)
	return track

func pose_gesture(rig: Skeleton3D, motion: Node3D, roots: Array[String], phase: float, group: int) -> void:
	var lean := 0.0
	var neck := 0.0
	var tail := 0.0
	match group:
		4:
			var strike := smoothstep(.21, .47, phase) * (1.0 - smoothstep(.57, .94, phase))
			var ready := sin(PI * phase) * (1.0 - smoothstep(.17, .36, phase))
			lean = .31 * strike - .25 * ready
			neck = .33 * strike
			tail = -.27 * strike
			motion.position.z = .041 * strike
		25:
			lean = .034 * sin(TAU * phase)
			neck = .064 * sin(TAU * phase)
			tail = .025 * sin(TAU * phase)
		28:
			lean = .25 * smoothstep(.26, .82, phase) - .13 * sin(PI * phase) * (1.0 - phase)
			neck = -.17 * sin(PI * phase) + .12 * smoothstep(.52, .91, phase)
			tail = -.09 * smoothstep(.32, .84, phase)
	pitch_body(rig, roots, lean)
	rotate_joint(rig, "Head", Vector3.RIGHT, neck)
	rotate_joint(rig, "Bone.006", Vector3.RIGHT, tail)
	for side: String in ["L", "R"]:
		rotate_joint(rig, "Leg_%s.001" % side, Vector3.RIGHT, -.66 * lean)
		rotate_joint(rig, "Leg_%s.002" % side, Vector3.RIGHT, -.24 * lean)
