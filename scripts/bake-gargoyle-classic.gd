extends "res://../scripts/bake-gargoyle-pillage-trial.gd"

const ART := "res://local-art/creatures/"
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const LUNGE_TIME := 1.15
const LUNGE_PHASES := [0.0, 0.17, 0.36, 0.57, 0.78, 1.0]
const LUNGE_DEPTH := [0.0, 0.32, 1.0, 1.0, 0.64, 0.0]
const STEP_DISTANCE := [0.0, 0.43, 1.0, 1.0, 0.83, 0.0]
const REACH := [0.0, 0.78, 0.48, -0.63, 0.23, 0.0]
const JOINTS := {
	"bip01 spine": [0.29, 0.0],
	"bip01 spine1": [0.21, 0.0],
	"bip01 head": [-0.21, 0.0],
	"bip01 l upperarm": [-0.55, -0.42],
	"bip01 r upperarm": [-0.51, 0.46],
	"bip01 l forearm": [-0.21, 0.18],
	"bip01 r forearm": [-0.24, -0.22],
}

func _initialize() -> void:
	create_timer(75.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var donor_path := ART + "gargoyle-4-cast-donor.gltf"
	assert(document.append_from_file(donor_path, state) == OK)
	var donor := document.generate_scene(state)
	var donor_player := donor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var receipt := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var source := ART + "gargoyles_gargoyle-" + treatment + ".gltf"
		var output := ART + "gargoyle-4-classic-" + treatment + ".scn"
		var model := (load(source) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var library := player.get_animation_library("")
		var cast := donor_player.get_animation("Cast").duplicate(true) as Animation
		assert(library.add_animation("Cast", cast) == OK)
		assert(library.add_animation("KneelingLunge", build_lunge(player, rig)) == OK)
		var space := model.find_child("SourceSpace", true, false) as Node3D
		assert(space != null)
		var skin := Ground.skin_points(mesh, rig)
		for clip in ["Cast", "KneelingLunge"]:
			fit_floor(player, rig, space, skin, clip)
		player.stop()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
		receipt[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
		model.free()
		print("GARGOYLE 4 ", treatment, ": recovered Cast and authored KneelingLunge")
	donor.free()
	var file := FileAccess.open(ART + "gargoyle-4-classic-bake.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"treatments": receipt, "recipe": FileAccess.get_sha256(get_script().resource_path),
		"donor": FileAccess.get_sha256(donor_path), "leg_solver": FileAccess.get_sha256("res://../scripts/bake-gargoyle-pillage-trial.gd")}))
	file.close()
	quit()

func build_lunge(player: AnimationPlayer, rig: Skeleton3D) -> Animation:
	var idle := player.get_animation("Idle")
	var motion := idle.duplicate(true) as Animation
	motion.length = LUNGE_TIME
	motion.loop_mode = Animation.LOOP_NONE
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var reference: Array[Transform3D] = []
	for bone in rig.get_bone_count():
		reference.append(rig.get_bone_pose(bone))
	for track in motion.get_track_count():
		var value: Variant = motion.track_get_key_value(track, 0)
		clear_keys(motion, track)
		motion.track_insert_key(track, 0.0, value)
	var names: Array = JOINTS.keys()
	names.append_array(["bip01 l thigh", "bip01 l calf", "bip01 l foot",
		"bip01 r thigh", "bip01 r calf", "bip01 r foot"])
	var wing_names := ["gargoyle l mainwing1", "gargoyle r mainwing1"]
	names.append_array(wing_names)
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var rotations := {}
	for name: String in names:
		rotations[name] = ensure_track(motion, NodePath("%s:%s" % [rig_path, name]), Animation.TYPE_ROTATION_3D)
	var pelvis := rig.find_bone("bip01 pelvis")
	var pelvis_track := ensure_track(motion, NodePath("%s:bip01 pelvis" % rig_path), Animation.TYPE_POSITION_3D)
	var basis := rig.global_basis.inverse()
	var up := (basis * Vector3.UP).normalized()
	var forward := (basis * Vector3.BACK).normalized()
	var right := (basis * Vector3.RIGHT).normalized()
	var phase := 0
	var intervals := roundi(LUNGE_TIME * 120.0)
	for index in intervals + 1:
		var u := float(index) / intervals
		while phase < LUNGE_PHASES.size() - 2 and u > LUNGE_PHASES[phase + 1]:
			phase += 1
		var mix := smoothstep(LUNGE_PHASES[phase], LUNGE_PHASES[phase + 1], u)
		var depth := lerpf(LUNGE_DEPTH[phase], LUNGE_DEPTH[phase + 1], mix)
		var step := lerpf(STEP_DISTANCE[phase], STEP_DISTANCE[phase + 1], mix)
		var reach := lerpf(REACH[phase], REACH[phase + 1], mix)
		for bone in reference.size():
			var pose := reference[bone]
			rig.set_bone_pose_position(bone, pose.origin)
			rig.set_bone_pose_rotation(bone, pose.basis.get_rotation_quaternion())
			rig.set_bone_pose_scale(bone, pose.basis.get_scale())
		rig.force_update_all_bone_transforms()
		if step > 0.0:
			var front := rig.get_bone_global_pose(rig.find_bone("bip01 l foot"))
			var rear := rig.get_bone_global_pose(rig.find_bone("bip01 r foot"))
			front.origin += forward * 0.49 * step + up * 0.10 * sin(PI * step)
			rear.origin += (-forward * 0.20 + up * 0.14) * step
			rear.basis = Basis(Quaternion(right, 0.51 * depth)) * rear.basis
			var hips := rig.get_bone_global_pose(pelvis)
			hips.origin += (forward * 0.15 - up * 0.47) * depth
			rig.set_bone_global_pose(pelvis, hips)
			rig.force_update_all_bone_transforms()
			for name: String in JOINTS:
				var weights: Array = JOINTS[name]
				rotate_bone(rig, name, right, float(weights[0]) * depth + float(weights[1]) * reach)
			for name in wing_names:
				rotate_bone(rig, name, right, 1.38 * depth)
			plant_leg(rig, "l", front, forward)
			plant_leg(rig, "r", rear, forward)
		var time := u * LUNGE_TIME
		for name: String in names:
			motion.rotation_track_insert_key(rotations[name], time, rig.get_bone_pose_rotation(rig.find_bone(name)))
		motion.position_track_insert_key(pelvis_track, time, rig.get_bone_pose_position(pelvis))
	player.stop()
	return motion

func fit_floor(player: AnimationPlayer, rig: Skeleton3D, space: Node3D, skin: Dictionary, clip: String) -> void:
	var motion := player.get_animation(clip)
	var path := player.get_node(player.root_node).get_path_to(space)
	var track := ensure_track(motion, path, Animation.TYPE_POSITION_3D)
	if motion.track_get_key_count(track) == 0:
		motion.position_track_insert_key(track, 0.0, space.position)
	var intervals := ceili(motion.length * 120.0)
	var offsets: Array[Vector3] = []
	var up := space.get_parent_node_3d().global_basis.inverse() * Vector3.UP
	player.play(clip, 0.0)
	player.advance(0.0)
	for i in intervals + 1:
		player.seek(motion.length * float(i) / intervals, true)
		rig.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		offsets.append(space.position + up * (0.001 - gap))
	player.stop()
	clear_keys(motion, track)
	for i in offsets.size():
		motion.position_track_insert_key(track, motion.length * float(i) / intervals, offsets[i])

func ensure_track(clip: Animation, path: NodePath, type: Animation.TrackType) -> int:
	var track := clip.find_track(path, type)
	if track < 0:
		track = clip.add_track(type)
		clip.track_set_path(track, path)
	return track

func clear_keys(clip: Animation, track: int) -> void:
	for key in range(clip.track_get_key_count(track) - 1, -1, -1):
		clip.track_remove_key(track, key)
