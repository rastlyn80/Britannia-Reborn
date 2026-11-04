extends "res://../scripts/bake-vampire-bat-actions.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const FITTED := ["BalronRake","BalronStagger","BalronGuard","BalronPause","AirDeath"]

func run() -> void:
	var treatments := {}
	var row := Registry.entry(40)
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
		var output_path := "res://local-art/creatures/balron-distinct-actions-%s.scn" % treatment
		assert(ResourceSaver.save(output, output_path, ResourceSaver.FLAG_COMPRESS) == OK)
		print("BALRON ",treatment,": five fitted motions, exact older source keys")
		treatments[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output_path)}
		model.free()
	var receipt := FileAccess.open("res://local-art/creatures/balron-distinct-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path), "scenes": treatments}))
	receipt.close()
	quit()

func build(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, label: String) -> Animation:
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	var length: float = {"BalronRake":0.64,"BalronStagger":0.46,"BalronGuard":0.44,"BalronPause":0.78,"AirDeath":1.24}[label]
	clip.length = length
	clip.loop_mode = Animation.LOOP_NONE
	var root_bone := rig.find_bone("bip01")
	var path := player.get_node(player.root_node).get_path_to(rig)
	var node_path := NodePath("VisualRoot/SourceSpace")
	var source_space := player.get_node(player.root_node).get_node(node_path) as Node3D
	var space_track := channel(clip,node_path,Animation.TYPE_POSITION_3D)
	var fixed_origin := source_space.position
	if clip.track_get_key_count(space_track)>0:
		fixed_origin = clip.track_get_key_value(space_track,0)
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
			desired += 1.55 * (1.0-smoothstep(0.37,1.0,phase))
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
	var flight_phase := 0.23 + 0.04*sin(TAU*phase)
	seek(player, rig, "Fly", flight_phase)
	var finish := smoothstep(0.48, 0.94, phase)
	if finish > 0.0:
		var pose: Array[Transform3D] = []
		for bone in rig.get_bone_count():
			pose.append(rig.get_bone_pose(bone))
		var terminal := lerpf(0.54,0.9999,smoothstep(0.48,1.0,phase))
		seek(player, rig, "Death", terminal)
		for bone in rig.get_bone_count():
			rig.set_bone_pose(bone, pose[bone].interpolate_with(rig.get_bone_pose(bone), finish))

func pose_gesture(player: AnimationPlayer, rig: Skeleton3D, label: String, phase: float) -> void:
	seek(player,rig,"Idle",0.0)
	var pulse := smoothstep(0.03,0.31,phase)*(1.0-smoothstep(0.54,1.0,phase))
	var answer := smoothstep(0.27,0.61,phase)*(1.0-smoothstep(0.72,1.0,phase))
	match label:
		"BalronRake":
			turn(rig,"bip01 spine1",Vector3.RIGHT,0.39*answer)
			turn(rig,"bip01 r upperarm",Vector3.RIGHT,0.32*pulse-1.12*answer)
			turn(rig,"bip01 r forearm",Vector3.UP,-0.24*answer)
			turn(rig,"daemon r mainwing01",Vector3.UP,0.35*answer)
			turn(rig,"bip01 l thigh",Vector3.RIGHT,-0.33*answer)
		"BalronStagger":
			turn(rig,"bip01 spine1",Vector3.FORWARD,0.31*pulse)
			turn(rig,"bip01 neck",Vector3.RIGHT,0.24*pulse)
			turn(rig,"daemon l mainwing01",Vector3.UP,-0.47*pulse)
			turn(rig,"bip01 l upperarm",Vector3.RIGHT,-0.53*pulse)
		"BalronGuard":
			turn(rig,"bip01 spine2",Vector3.UP,0.33*pulse)
			turn(rig,"bip01 r upperarm",Vector3.RIGHT,-0.66*pulse)
			turn(rig,"bip01 r forearm",Vector3.RIGHT,-0.46*pulse)
			turn(rig,"daemon r mainwing02",Vector3.UP,0.26*answer)
		"BalronPause":
			turn(rig,"bip01 head",Vector3.UP,0.24*pulse)
			turn(rig,"bip01 tail",Vector3.UP,-0.41*answer)
			turn(rig,"bip01 tail1",Vector3.UP,-0.32*answer)
			turn(rig,"daemon l mainwing02",Vector3.RIGHT,0.16*pulse)

func turn(rig: Skeleton3D, label: String, axis: Vector3, amount: float) -> void:
	var bone := rig.find_bone(label)
	assert(bone >= 0)
	var pose := rig.get_bone_global_pose(bone)
	pose.basis = Basis(Quaternion((rig.global_basis.inverse()*axis).normalized(), amount)) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()
