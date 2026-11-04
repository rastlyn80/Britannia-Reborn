extends "res://../scripts/bake-vampire-bat-actions.gd"

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const JOINTS := ["upper mass","arm l1","atm l2","arm r1","arm r2","face4 jaw1",
	"face5 jaw1","tendril1","tendril3","tendril5","tentaclea 1","tentacleb 1"]

func run() -> void:
	var treatments := {}
	var base := Registry.entry(775)
	for treatment: String in ["original","rounded","modern"]:
		var path := Registry.asset_path(base,treatment)
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var player := model.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
		var rig := model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
		var mesh := model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh,rig)
		var lib := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("",lib)
		for label: String in ["MassRecoil","TendrilRipple"]:
			assert(lib.add_animation(label,build(player,rig,skin,label))==OK)
		Exact.check_earlier_keys(player,path)
		player.stop()
		var packed := PackedScene.new()
		assert(packed.pack(model)==OK)
		var output := "res://local-art/creatures/plague-beast-distinct-actions-%s.scn" % treatment
		assert(ResourceSaver.save(packed,output,ResourceSaver.FLAG_COMPRESS)==OK)
		treatments[treatment] = {"source": FileAccess.get_sha256(path), "scene": FileAccess.get_sha256(output)}
		model.free()
		print("PLAGUE BEAST ",treatment,": two gestures, source motions untouched")
	var receipt := FileAccess.open("res://local-art/creatures/plague-beast-distinct-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path), "scenes": treatments}))
	receipt.close()
	quit()

func build(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, label: String) -> Animation:
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	clip.length = 0.42 if label=="MassRecoil" else 0.83
	clip.loop_mode = Animation.LOOP_NONE
	for track in clip.get_track_count():
		for key in range(clip.track_get_key_count(track)-1,0,-1):
			clip.track_remove_key(track,key)
	var path := player.get_node(player.root_node).get_path_to(rig)
	var placement := channel(clip,NodePath("%s:bip 01" % path),Animation.TYPE_POSITION_3D)
	var tracks := {}
	for joint: String in JOINTS:
		tracks[joint]=channel(clip,NodePath("%s:%s" % [path,joint]),Animation.TYPE_ROTATION_3D)
		clear_keys(clip,tracks[joint])
	clear_keys(clip,placement)
	player.play("Idle",0.0)
	player.advance(0.0)
	var root_joint := rig.find_bone("bip 01")
	for frame in 81:
		var phase := float(frame)/80.0
		rig.reset_bone_poses()
		player.seek(0.0,true)
		rig.force_update_all_bone_transforms()
		var pulse := smoothstep(0.04,0.34,phase)*(1.0-smoothstep(0.52,1.0,phase))
		var response := smoothstep(0.25,0.58,phase)*(1.0-smoothstep(0.72,1.0,phase))
		if label=="MassRecoil":
			turn(rig,"upper mass",Vector3.RIGHT,-0.22*pulse)
			turn(rig,"arm l1",Vector3.UP,0.31*pulse)
			turn(rig,"atm l2",Vector3.RIGHT,0.23*pulse)
			turn(rig,"arm r1",Vector3.UP,-0.18*response)
			turn(rig,"face4 jaw1",Vector3.RIGHT,0.16*pulse)
			turn(rig,"tendril1",Vector3.FORWARD,-0.29*pulse)
		else:
			turn(rig,"upper mass",Vector3.FORWARD,0.12*pulse-0.11*response)
			turn(rig,"arm l1",Vector3.RIGHT,-0.20*pulse)
			turn(rig,"arm r2",Vector3.RIGHT,-0.17*response)
			turn(rig,"face5 jaw1",Vector3.RIGHT,0.19*response)
			turn(rig,"tendril1",Vector3.RIGHT,0.28*pulse)
			turn(rig,"tendril3",Vector3.RIGHT,0.33*response)
			turn(rig,"tendril5",Vector3.BACK,0.21*response)
			turn(rig,"tentaclea 1",Vector3.UP,-0.29*pulse)
			turn(rig,"tentacleb 1",Vector3.UP,0.29*response)
		var gap := Ground.minimum_plane_gap(skin,rig,rig.global_transform,Vector3.ZERO,Vector3.UP)
		var root_pose := rig.get_bone_global_pose(root_joint)
		root_pose.origin += rig.global_basis.inverse()*Vector3.UP*(0.003-gap)
		rig.set_bone_global_pose(root_joint,root_pose)
		for joint: String in tracks:
			clip.rotation_track_insert_key(tracks[joint],phase*clip.length,rig.get_bone_pose_rotation(rig.find_bone(joint)))
		clip.position_track_insert_key(placement,phase*clip.length,rig.get_bone_pose_position(root_joint))
	return clip

func channel(clip: Animation, path: NodePath, type: Animation.TrackType) -> int:
	var track := clip.find_track(path,type)
	if track<0:
		track=clip.add_track(type)
		clip.track_set_path(track,path)
	return track

func turn(rig: Skeleton3D, joint: String, axis: Vector3, amount: float) -> void:
	var bone := rig.find_bone(joint)
	assert(bone>=0)
	var pose := rig.get_bone_global_pose(bone)
	pose.basis=Basis(Quaternion((rig.global_basis.inverse()*axis).normalized(),amount))*pose.basis
	rig.set_bone_global_pose(bone,pose)
	rig.force_update_all_bone_transforms()
