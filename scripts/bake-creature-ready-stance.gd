extends SceneTree
## Group 25 ready stances referenced by classic group 11 on Raptor and Slith.

const LENGTH := 1.0
const SAMPLES := 120
const RAPTOR := "res://local-art/creatures/raptor/raptor.scn"
const SLITH := "res://local-art/creatures/slith/lizards_komodo_dragon-%s.gltf"
const OUTPUT := "res://local-art/creatures/ready-stance-%d-%s.scn"
## Joint, pitch and yaw in degrees, followed by cycle pitch and yaw amplitudes.
const RAPTOR_JOINTS := [
	["Torso", -10.0, 0.0, 0.8, 0.0], ["Shoulders", -6.0, 0.0, 0.8, 0.0],
	["Neck", -12.0, 0.0, 1.5, 0.7], ["Head", 7.0, 0.0, 1.4, 0.8],
	["FrontUpLeg.R", 17.0, 0.0, 1.4, 0.0], ["FrontUpLeg.L", 17.0, 0.0, 1.4, 0.0],
	["FrontLowLeg.R", 8.0, 0.0, 1.0, 0.0], ["FrontLowLeg.L", 8.0, 0.0, 1.0, 0.0],
	["Tail1", -17.0, 0.0, 1.1, 1.2], ["Tail2", -9.0, 0.0, 0.8, -1.5],
]
const SLITH_JOINTS := [
	["bip01 neck1", -13.0, 0.0, 1.1, 1.0], ["bip01 head", 5.0, 0.0, 0.8, 1.2],
	["bip01 tail", 0.0, -2.0, 0.5, 1.2], ["bip01 tail1", 0.0, 2.0, 0.5, -1.8],
	["bip01 tail2", 0.0, 0.0, 0.7, 1.0],
]

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	if not bake(730, "shared", RAPTOR, RAPTOR_JOINTS):
		quit(1)
		return
	for treatment in ["original", "rounded", "modern"]:
		if not bake(734, treatment, SLITH % treatment, SLITH_JOINTS):
			quit(1)
			return
	quit()

func bake(body: int, treatment: String, path: String, joints: Array) -> bool:
	var model := (load(path) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("")
	assert(not library.has_animation("ReadyStance"))
	var motion := library.get_animation("Idle").duplicate(true) as Animation
	motion.length = LENGTH
	motion.loop_mode = Animation.LOOP_NONE
	var tracks := {}
	for track in motion.get_track_count():
		var value: Variant = motion.track_get_key_value(track, 0)
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		motion.track_insert_key(track, 0.0, value)
		var track_path := motion.track_get_path(track)
		if motion.track_get_type(track) == Animation.TYPE_ROTATION_3D and track_path.get_subname_count() == 1:
			tracks[str(track_path.get_subname(0))] = track
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	player.play("Idle")
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var base: Array[Quaternion] = []
	for joint: Array in joints:
		var bone := rig.find_bone(joint[0])
		assert(bone >= 0)
		base.append(rig.get_bone_pose_rotation(bone))
		if not tracks.has(joint[0]):
			tracks[joint[0]] = motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(tracks[joint[0]], NodePath("%s:%s" % [rig_path, joint[0]]))
	var right := (rig.global_basis.inverse() * Vector3.RIGHT).normalized()
	var up := (rig.global_basis.inverse() * Vector3.UP).normalized()
	for index in SAMPLES + 1:
		var fraction := float(index) / SAMPLES
		for i in joints.size():
			rig.set_bone_pose_rotation(rig.find_bone(joints[i][0]), base[i])
		for joint: Array in joints:
			rig.force_update_all_bone_transforms()
			var bone := rig.find_bone(joint[0])
			var pose := rig.get_bone_global_pose(bone)
			var pitch := deg_to_rad(joint[1] + joint[3] * sin(TAU * fraction))
			var yaw := deg_to_rad(joint[2] + joint[4] * sin(TAU * fraction))
			pose.basis = Basis(Quaternion(up, yaw) * Quaternion(right, pitch)) * pose.basis
			rig.set_bone_global_pose(bone, pose)
			motion.rotation_track_insert_key(tracks[joint[0]], LENGTH * fraction, rig.get_bone_pose_rotation(bone))
	assert(library.add_animation("ReadyStance", motion) == OK)
	player.stop()
	var scene := PackedScene.new()
	var saved := scene.pack(model) == OK and ResourceSaver.save(scene, OUTPUT % [body, treatment], ResourceSaver.FLAG_COMPRESS) == OK
	model.free()
	print("READY STANCE ", body, " ", treatment, ": ", SAMPLES + 1, " pose keys over one second")
	return saved
