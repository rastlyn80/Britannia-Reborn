extends SceneTree
## Body 831, classic slot 19. Authored against one eight-frame UOP direction.

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const SOURCE := "res://local-art/creatures/late_donors/birds_parrot-%s.gltf"
const OUTPUT := "res://local-art/creatures/parrot-831-flight-trial-%s.scn"
const LENGTH := 0.80
const ELEVATION := [63.0, 25.0, -25.0, -56.0, -56.0, -28.0, 20.0, 63.0]
const FLEX := [12.0, 5.0, -4.0, -9.0, -8.0, 1.0, 9.0, 12.0]
const WING_JOINTS := ["clavicle", "upperarm", "forearm", "hand", "finger0", "finger01", "finger1", "finger11"]

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	for treatment in ["original", "rounded", "modern"]:
		if not bake(treatment):
			quit(1)
			return
	quit()

func bake(treatment: String) -> bool:
	var model := (load(SOURCE % treatment) as PackedScene).instantiate()
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var library := player.get_animation_library("")
	var motion := library.get_animation("Idle").duplicate(true) as Animation
	motion.length = LENGTH
	motion.loop_mode = Animation.LOOP_NONE
	var tracks := {}
	for track in motion.get_track_count():
		var value: Variant = motion.track_get_key_value(track, 0)
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		motion.track_insert_key(track, 0.0, value)
		var path := motion.track_get_path(track)
		if path.get_subname_count() == 1:
			tracks[[str(path.get_subname(0)), motion.track_get_type(track)]] = track
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var pelvis := rig.find_bone("bip01 pelvis")
	var thighs := [rig.find_bone("bip01 l thigh"), rig.find_bone("bip01 r thigh")]
	var wings: Array[Array] = []
	for side in ["l", "r"]:
		var chain: Array[int] = []
		for joint in WING_JOINTS:
			var bone := rig.find_bone("bip01 %s %s" % [side, joint])
			assert(bone >= 0)
			chain.append(bone)
		wings.append(chain)
	var data := Ground.skin_points(mesh, rig)
	var world_to_rig := rig.global_basis.inverse()
	var forward := (world_to_rig * Vector3.BACK).normalized()
	var right := (world_to_rig * Vector3.RIGHT).normalized()
	var positions := PackedVector3Array()
	var lowest := INF
	player.play("Idle")
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var base_pelvis := rig.get_bone_pose_position(pelvis)
	rotate_joint(rig, pelvis, right, deg_to_rad(22.0))
	write_key(motion, tracks, rig_path, rig.get_bone_name(pelvis), Animation.TYPE_ROTATION_3D,
		0.0, rig.get_bone_pose_rotation(pelvis))
	for bone: int in thighs:
		assert(bone >= 0)
		rotate_joint(rig, bone, right, deg_to_rad(12.0))
		write_key(motion, tracks, rig_path, rig.get_bone_name(bone), Animation.TYPE_ROTATION_3D,
			0.0, rig.get_bone_pose_rotation(bone))
	var frame_count := roundi(LENGTH * 120.0)
	for frame in frame_count + 1:
		var time := LENGTH * float(frame) / frame_count
		var phase := float(frame) * (ELEVATION.size() - 1) / frame_count
		var first := mini(floori(phase), ELEVATION.size() - 2)
		var blend := smoothstep(0.0, 1.0, phase - first)
		for side in wings.size():
			var chain := wings[side]
			var direction := 1.0 if side == 0 else -1.0
			for bone: int in chain:
				rig.set_bone_pose_rotation(bone, rig.get_bone_rest(bone).basis.get_rotation_quaternion())
			var sweep := lerpf(ELEVATION[first], ELEVATION[first + 1], blend)
			var flex := lerpf(FLEX[first], FLEX[first + 1], blend)
			rotate_joint(rig, chain[0], forward, deg_to_rad(direction * sweep))
			rotate_joint(rig, chain[2], forward, deg_to_rad(direction * flex))
			for bone: int in chain:
				write_key(motion, tracks, rig_path, rig.get_bone_name(bone), Animation.TYPE_ROTATION_3D,
					time, rig.get_bone_pose_rotation(bone))
		rig.force_update_all_bone_transforms()
		var lift := 0.035 * cos(TAU * float(frame) / frame_count)
		var local_lift := world_to_rig * Vector3.UP * lift
		var parent := rig.get_bone_parent(pelvis)
		var pose := base_pelvis + rig.get_bone_global_pose(parent).basis.inverse() * local_lift
		rig.set_bone_pose_position(pelvis, pose)
		rig.force_update_all_bone_transforms()
		lowest = minf(lowest, Ground.minimum_plane_gap(data, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		positions.append(pose)
	var parent := rig.get_bone_parent(pelvis)
	var clearance := rig.get_bone_global_pose(parent).basis.inverse() * (world_to_rig * Vector3.UP * (0.08 - lowest))
	for frame in positions.size():
		var time := LENGTH * float(frame) / frame_count
		write_key(motion, tracks, rig_path, "bip01 pelvis", Animation.TYPE_POSITION_3D, time, positions[frame] + clearance)
	library.add_animation("Fly", motion)
	player.stop()
	var scene := PackedScene.new()
	var saved := scene.pack(model) == OK and ResourceSaver.save(scene, OUTPUT % treatment, ResourceSaver.FLAG_COMPRESS) == OK
	model.free()
	print("PARROT 831 FLIGHT: ", treatment, ", eight reference poses, ", frame_count + 1,
		" samples, cycle floor correction ", 0.08 - lowest)
	return saved

func rotate_joint(rig: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	rig.force_update_all_bone_transforms()
	var pose := rig.get_bone_global_pose(bone)
	pose.basis = Basis(Quaternion(axis, angle)) * pose.basis
	rig.set_bone_global_pose(bone, pose)

func write_key(clip: Animation, tracks: Dictionary, rig_path: NodePath, bone: String, type: int,
		time: float, value: Variant) -> void:
	var key := [bone, type]
	if not tracks.has(key):
		tracks[key] = clip.add_track(type)
		clip.track_set_path(tracks[key], NodePath("%s:%s" % [rig_path, bone]))
	clip.track_insert_key(tracks[key], time, value)
