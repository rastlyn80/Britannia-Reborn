extends "res://../scripts/bake-vampire-bat-actions.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const FITTED := ["BankRecoil", "WingPulse", "AirDeath"]

func run() -> void:
	var treatments := {}
	var row := Registry.entry(317)
	for treatment: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(row, treatment)
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var player := model.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
		var rig := model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
		var mesh := model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh, rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		for clip: String in FITTED:
			assert(library.add_animation(clip, build(player, rig, skin, clip)) == OK)
		Exact.check_earlier_keys(player, source)
		player.stop()
		var output := PackedScene.new()
		assert(output.pack(model) == OK)
		var output_path := "res://local-art/creatures/vampire-bat-distinct-actions-%s.scn" % treatment
		assert(ResourceSaver.save(output, output_path, ResourceSaver.FLAG_COMPRESS) == OK)
		print("BAT ", treatment, ": three fitted motions, exact old wing and death keys")
		treatments[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output_path)}
		model.free()
	var receipt := FileAccess.open("res://local-art/creatures/vampire-bat-distinct-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path), "scenes": treatments}))
	receipt.close()
	quit()

func build(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, label: String) -> Animation:
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	var length: float = {"BankRecoil":0.43, "WingPulse":0.71, "AirDeath":1.12}[label]
	clip.length = length
	clip.loop_mode = Animation.LOOP_NONE
	var root_bone := rig.find_bone("bip01")
	var path := player.get_node(player.root_node).get_path_to(rig)
	var node_path := NodePath("VisualRoot/SourceSpace")
	var source_space := player.get_node(player.root_node).get_node(node_path) as Node3D
	var space_track := clip.find_track(node_path, Animation.TYPE_POSITION_3D)
	assert(space_track >= 0)
	var fixed_origin: Vector3 = clip.track_get_key_value(space_track, 0)
	var rotation: Array[int] = []
	var position: Array[int] = []
	var scale: Array[int] = []
	for bone in rig.get_bone_count():
		var key := NodePath("%s:%s" % [path, rig.get_bone_name(bone)])
		rotation.append(channel(clip, key, Animation.TYPE_ROTATION_3D))
		position.append(channel(clip, key, Animation.TYPE_POSITION_3D))
		scale.append(channel(clip, key, Animation.TYPE_SCALE_3D))
	for track in clip.get_track_count():
		clear_keys(clip, track)
	clip.position_track_insert_key(space_track, 0.0, fixed_origin)
	var minima := INF
	for index in 121:
		var phase := float(index) / 120.0
		if label == "AirDeath":
			pose_fall(player, rig, phase)
		else:
			pose_gesture(player, rig, label, phase)
		rig.force_update_all_bone_transforms()
		source_space.position = fixed_origin
		source_space.force_update_transform()
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var desired := 0.004
		if label == "AirDeath":
			desired += 0.24 * (1.0 - smoothstep(0.49, 1.0, phase)) + 0.12 * sin(PI * phase) * (1.0 - phase)
		elif label == "WingPulse":
			desired += 0.08 * sin(PI * phase)
		var placement := rig.get_bone_global_pose(root_bone)
		placement.origin += rig.global_basis.inverse() * Vector3.UP * (desired - gap)
		rig.set_bone_global_pose(root_bone, placement)
		rig.force_update_all_bone_transforms()
		minima = minf(minima, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		for bone in rig.get_bone_count():
			clip.rotation_track_insert_key(rotation[bone], phase * length, rig.get_bone_pose_rotation(bone))
			clip.position_track_insert_key(position[bone], phase * length, rig.get_bone_pose_position(bone))
			clip.scale_track_insert_key(scale[bone], phase * length, rig.get_bone_pose_scale(bone))
	print(label, " least floor ", minima)
	assert(minima > 0.002)
	return clip

func channel(clip: Animation, path: NodePath, type: Animation.TrackType) -> int:
	var track := clip.find_track(path,type)
	if track < 0:
		track = clip.add_track(type)
		clip.track_set_path(track,path)
	return track

func seek(player: AnimationPlayer, rig: Skeleton3D, clip: String, phase: float) -> void:
	player.play(clip, 0.0)
	player.advance(0.0)
	rig.reset_bone_poses()
	player.seek(player.current_animation_length * phase, true)
	rig.force_update_all_bone_transforms()

func pose_fall(player: AnimationPlayer, rig: Skeleton3D, phase: float) -> void:
	var flight_phase := fmod(phase * 2.65 + 0.06, 1.0)
	seek(player, rig, "Walk", flight_phase)
	var finish := smoothstep(0.48, 0.94, phase)
	if finish > 0.0:
		var pose: Array[Transform3D] = []
		for bone in rig.get_bone_count():
			pose.append(rig.get_bone_pose(bone))
		var terminal := lerpf(0.59, 0.9999, smoothstep(0.48, 1.0, phase))
		seek(player, rig, "Death", terminal)
		for bone in rig.get_bone_count():
			rig.set_bone_pose(bone, pose[bone].interpolate_with(rig.get_bone_pose(bone), finish))

func pose_gesture(player: AnimationPlayer, rig: Skeleton3D, label: String, phase: float) -> void:
	seek(player, rig, "Idle", 0.0)
	var recoil := smoothstep(0.04, 0.29, phase) * (1.0 - smoothstep(0.48, 1.0, phase))
	var settle := smoothstep(0.28, 0.62, phase) * (1.0 - smoothstep(0.70, 1.0, phase))
	turn(rig, "bip01", Vector3.BACK, (0.33 * recoil - 0.16 * settle) if label == "BankRecoil" else 0.04 * recoil)
	turn(rig, "bip01 head", Vector3.RIGHT, 0.23 * recoil - 0.15 * settle)
	for side: String in ["l","r"]:
		var sign := -1.0 if side == "l" else 1.0
		var flap := (0.63 if side == "l" else 0.27) * recoil - 0.28 * settle
		if label == "WingPulse":
			flap = 0.57 * recoil - 0.60 * settle
		turn(rig, "bip01 " + side + " upperarm", Vector3.BACK, sign * flap)
		turn(rig, "bip01 " + side + " forearm", Vector3.UP, sign * (0.22 * recoil + 0.26 * settle))
		turn(rig, "wing" + side + "2", Vector3.BACK, sign * 0.12 * settle)

func turn(rig: Skeleton3D, label: String, axis: Vector3, amount: float) -> void:
	var bone := rig.find_bone(label)
	assert(bone >= 0)
	var pose := rig.get_bone_global_pose(bone)
	pose.basis = Basis(Quaternion((rig.global_basis.inverse()*axis).normalized(), amount)) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()
