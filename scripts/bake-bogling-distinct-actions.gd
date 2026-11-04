extends SceneTree
const SOURCE := "res://Art/Creatures/Bogling/bogling.glb"
const OUT := "res://local-art/creatures/bogling-distinct-actions.res"
const SCENE := "res://local-art/creatures/bogling-distinct-candidate.scn"
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const JOINTS := ["spine.002","spine.003","upper_arm.L","upper_arm.R","forearm.L","forearm.R"]

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var model := (load(SOURCE) as PackedScene).instantiate()
	root.add_child(model)
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK and ResourceSaver.save(scene, SCENE, ResourceSaver.FLAG_COMPRESS) == OK)
	var player := model.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	var rig := model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var mesh := model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh,rig)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library := AnimationLibrary.new()
	for clip: String in ["RootGuard","Uncurl"]:
		var motion := build(player,rig,clip)
		assert(library.add_animation(clip,motion) == OK)
		assert(player.get_animation_library("").add_animation(clip,motion) == OK)
		player.play(clip,0.0)
		player.advance(0.0)
		var minimum := INF
		for frame in 121:
			player.seek(player.current_animation_length*float(frame)/120.0,true)
			rig.force_update_all_bone_transforms()
			minimum = minf(minimum,Ground.minimum_plane_gap(skin,rig,rig.global_transform,Vector3.ZERO,Vector3.UP))
		print(clip," floor ",minimum)
		assert(minimum > -0.015)
	assert(ResourceSaver.save(library,OUT,ResourceSaver.FLAG_COMPRESS)==OK)
	model.free()
	print("BOGLING: 242 poses on the pinned public rig; two fitted gestures")
	quit()

func build(player: AnimationPlayer, rig: Skeleton3D, name: String) -> Animation:
	var idle := player.get_animation("Idle")
	var clip := idle.duplicate(true) as Animation
	clip.length = 0.42 if name == "RootGuard" else 0.78
	clip.loop_mode = Animation.LOOP_NONE
	var tracks := {}
	var path := player.get_node(player.root_node).get_path_to(rig)
	for joint: String in JOINTS:
		var target := NodePath("%s:%s" % [path,joint])
		var track := clip.find_track(target,Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(track,target)
		tracks[joint] = track
		for key in range(clip.track_get_key_count(track)-1,-1,-1):
			clip.track_remove_key(track,key)
	player.play("Idle",0.0)
	player.advance(0.0)
	for frame in 81:
		var phase := float(frame)/80.0
		player.seek(0.0,true)
		rig.force_update_all_bone_transforms()
		var pulse := smoothstep(0.04,0.40,phase) * (1.0-smoothstep(0.53,1.0,phase))
		if name == "RootGuard":
			turn(rig,"spine.002",Vector3.UP,-0.23*pulse)
			turn(rig,"spine.003",Vector3.RIGHT,-0.13*pulse)
			turn(rig,"forearm.L",Vector3.RIGHT,-0.48*pulse)
			turn(rig,"upper_arm.R",Vector3.FORWARD,0.11*pulse)
		else:
			turn(rig,"spine.002",Vector3.RIGHT,-0.32*pulse)
			turn(rig,"spine.003",Vector3.RIGHT,-0.24*pulse)
			turn(rig,"upper_arm.L",Vector3.RIGHT,0.28*pulse)
			turn(rig,"upper_arm.R",Vector3.RIGHT,0.38*pulse)
			turn(rig,"forearm.L",Vector3.UP,0.12*pulse)
		for joint: String in tracks:
			clip.rotation_track_insert_key(tracks[joint],phase*clip.length,rig.get_bone_pose_rotation(rig.find_bone(joint)))
	return clip

func turn(rig: Skeleton3D, joint: String, axis: Vector3, angle: float) -> void:
	var bone := rig.find_bone(joint)
	assert(bone >= 0)
	var pose := rig.get_bone_global_pose(bone)
	pose.basis = Basis(Quaternion((rig.global_basis.inverse()*axis).normalized(),angle))*pose.basis
	rig.set_bone_global_pose(bone,pose)
	rig.force_update_all_bone_transforms()


