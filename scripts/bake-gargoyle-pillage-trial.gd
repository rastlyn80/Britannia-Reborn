extends SceneTree
## Authored replacements for the original slot 11 frame sequences.

const SOURCE := "res://local-art/creatures/gargoyles_gargoyle_slave-%s.scn"
const OUTPUT := "res://local-art/creatures/gargoyle-753-pillage-trial%s.scn"
const LENGTH := 1.30
# Crouch, then two alternating reaches and a return to the original idle pose.
const POSES := [
	[0.0, 0.0, 0.0], [0.10, 0.78, 0.20], [0.19, 1.0, 0.64],
	[0.29, 1.0, 0.35], [0.39, 0.92, -0.65], [0.49, 0.88, -0.35],
	[0.59, 1.0, 0.75], [0.69, 0.96, 0.37], [0.79, 0.93, -0.58],
	[0.89, 0.92, -0.28], [1.0, 0.68, 0.10], [1.12, 0.31, 0.0],
	[LENGTH, 0.0, 0.0],
]
const BLISTERING_SOURCE := "res://local-art/creatures/gargoyles_gargoyle_blistering-%s.gltf"
const BLISTERING_OUTPUT := "res://local-art/creatures/gargoyle-130-pillage-trial%s.scn"
const BLISTERING_LENGTH := 1.10
const BLISTERING_POSES := [
	[0.0, 0.0, 0.0], [0.11, 0.53, 0.18], [0.22, 0.92, 0.70],
	[0.33, 1.0, 0.42], [0.44, 0.92, -0.60], [0.55, 0.98, -0.35],
	[0.66, 1.0, 0.58], [0.77, 0.91, -0.52], [0.88, 0.64, -0.16],
	[0.99, 0.26, 0.0], [BLISTERING_LENGTH, 0.0, 0.0],
]

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func rotate_bone(rig: Skeleton3D, name: String, axis: Vector3, angle: float) -> void:
	var bone := rig.find_bone(name)
	assert(bone >= 0)
	var pose := rig.get_bone_global_pose(bone)
	pose.basis = Basis(Quaternion(axis, angle)) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()

func aim(rig: Skeleton3D, bone: int, child: int, target: Vector3) -> void:
	var pose := rig.get_bone_global_pose(bone)
	var from := (rig.get_bone_global_pose(child).origin - pose.origin).normalized()
	var to := (target - pose.origin).normalized()
	pose.basis = Basis(Quaternion(from, to)) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()

func plant_leg(rig: Skeleton3D, side: String, ankle: Transform3D, forward: Vector3) -> void:
	var hip := rig.find_bone("bip01 %s thigh" % side)
	var knee := rig.find_bone("bip01 %s calf" % side)
	var foot := rig.find_bone("bip01 %s foot" % side)
	var a := rig.get_bone_global_pose(hip).origin
	var b := rig.get_bone_global_pose(knee).origin
	var c := rig.get_bone_global_pose(foot).origin
	var upper := a.distance_to(b)
	var lower := b.distance_to(c)
	var direction := (ankle.origin - a).normalized()
	var distance := minf(a.distance_to(ankle.origin), upper + lower - 0.0001)
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var pole := (forward - direction * direction.dot(forward)).normalized()
	var bend := sqrt(maxf(0.0, upper * upper - along * along))
	aim(rig, hip, knee, a + direction * along + pole * bend)
	aim(rig, knee, foot, ankle.origin)
	var rotation := rig.get_bone_global_pose(foot)
	rotation.basis = ankle.basis
	rig.set_bone_global_pose(foot, rotation)

func run() -> void:
	var blistering := "--blistering" in OS.get_cmdline_user_args()
	for treatment in ["original", "rounded", "modern"]:
		bake(treatment, blistering)
	quit()

func bake(treatment: String, blistering: bool) -> void:
	var source_pattern := BLISTERING_SOURCE if blistering else SOURCE
	var output_pattern := BLISTERING_OUTPUT if blistering else OUTPUT
	var length := BLISTERING_LENGTH if blistering else LENGTH
	var poses := BLISTERING_POSES if blistering else POSES
	var model := (load(source_pattern % treatment) as PackedScene).instantiate()
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var library := player.get_animation_library("")
	var idle := library.get_animation("Idle")
	var motion := idle.duplicate(true) as Animation
	motion.length = length
	motion.loop_mode = Animation.LOOP_NONE
	var tracks: Dictionary = {}
	for track in motion.get_track_count():
		var value: Variant = motion.track_get_key_value(track, 0)
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		motion.track_insert_key(track, 0.0, value)
		var path := motion.track_get_path(track)
		if path.get_subname_count() == 1:
			tracks[[str(path.get_subname(0)), motion.track_get_type(track)]] = track
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var right := (rig.global_basis.inverse() * Vector3.RIGHT).normalized()
	var up := (rig.global_basis.inverse() * Vector3.UP).normalized()
	var forward := (rig.global_basis.inverse() * Vector3.BACK).normalized()
	var pelvis := rig.find_bone("bip01 pelvis")
	var modified := ["spine", "spine1", "spine2", "head", "r thigh", "l thigh", "r calf", "l calf",
		"r foot", "l foot", "r upperarm", "l upperarm", "r forearm", "l forearm"]
	player.play("Idle")
	player.advance(0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var idle_pose: Array[Transform3D] = []
	for bone in rig.get_bone_count():
		idle_pose.append(rig.get_bone_pose(bone))
	var phase := 0
	var intervals := roundi(length * 120.0)
	for index in intervals + 1:
		var time := length * float(index) / float(intervals)
		while phase + 1 < poses.size() - 1 and time > float(poses[phase + 1][0]):
			phase += 1
		var from: Array = poses[phase]
		var to: Array = poses[phase + 1]
		var blend := smoothstep(float(from[0]), float(to[0]), time)
		for bone in rig.get_bone_count():
			var pose := idle_pose[bone]
			rig.set_bone_pose_position(bone, pose.origin)
			rig.set_bone_pose_rotation(bone, pose.basis.get_rotation_quaternion())
			rig.set_bone_pose_scale(bone, pose.basis.get_scale())
		rig.force_update_all_bone_transforms()
		var ankle_r := rig.get_bone_global_pose(rig.find_bone("bip01 r foot"))
		var ankle_l := rig.get_bone_global_pose(rig.find_bone("bip01 l foot"))
		var crouch := lerpf(float(from[1]), float(to[1]), blend)
		var reach := lerpf(float(from[2]), float(to[2]), blend)
		if crouch > 0.0:
			var hips := rig.get_bone_global_pose(pelvis)
			hips.origin -= (up * 0.34 + forward * 0.10) * crouch
			rig.set_bone_global_pose(pelvis, hips)
			rig.force_update_all_bone_transforms()
			rotate_bone(rig, "bip01 spine", right, 0.35 * crouch)
			rotate_bone(rig, "bip01 spine1", right, 0.24 * crouch)
			rotate_bone(rig, "bip01 spine2", up, reach * 0.21)
			rotate_bone(rig, "bip01 head", right, -0.20 * crouch)
			rotate_bone(rig, "bip01 r upperarm", right, -(0.49 * crouch + maxf(reach, 0.0) * 0.52))
			rotate_bone(rig, "bip01 l upperarm", right, -(0.49 * crouch + maxf(-reach, 0.0) * 0.52))
			rotate_bone(rig, "bip01 r forearm", right, -(0.29 * crouch - maxf(reach, 0.0) * 0.23))
			rotate_bone(rig, "bip01 l forearm", right, -(0.29 * crouch - maxf(-reach, 0.0) * 0.23))
			plant_leg(rig, "r", ankle_r, forward)
			plant_leg(rig, "l", ankle_l, forward)
		for name: String in modified:
			var key := ["bip01 " + name, Animation.TYPE_ROTATION_3D]
			if not tracks.has(key):
				tracks[key] = motion.add_track(Animation.TYPE_ROTATION_3D)
				motion.track_set_path(tracks[key], NodePath("%s:%s" % [rig_path, key[0]]))
			motion.rotation_track_insert_key(tracks[key], time, rig.get_bone_pose_rotation(rig.find_bone(key[0])))
		var key := ["bip01 pelvis", Animation.TYPE_POSITION_3D]
		if not tracks.has(key):
			tracks[key] = motion.add_track(Animation.TYPE_POSITION_3D)
			motion.track_set_path(tracks[key], NodePath("%s:%s" % [rig_path, key[0]]))
		motion.position_track_insert_key(tracks[key], time, rig.get_bone_pose_position(pelvis))
	library.add_animation("Pillage", motion)
	player.stop()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	var suffix := "" if treatment == "modern" else "-" + treatment
	assert(ResourceSaver.save(scene, output_pattern % suffix, ResourceSaver.FLAG_COMPRESS) == OK)
	print("GARGOYLE ", 130 if blistering else 753, " TRIAL: ", treatment,
		" ", poses.size(), " authored pose targets, baked at 120 Hz")
	model.free()
