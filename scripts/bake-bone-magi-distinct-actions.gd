extends "res://../scripts/bake-skeletal-mage-staff.gd"

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const GESTURES := ["StaffPush","StaffSlash","StaffRecoil","StaffRaise"]

func run() -> void:
	var treatments := {}
	var row := Registry.entry(148)
	for treatment: String in ["original","rounded","modern"]:
		var source := Registry.asset_path(row,treatment)
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var player := model.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
		var rig := model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
		var body := model.find_children("*","MeshInstance3D",true,false)[0] as MeshInstance3D
		var prop := rig.get_node("SkeletonMageStaff") as MeshInstance3D
		var staff := rig.find_bone(BONE)
		var grip := rig.get_bone_parent(staff)
		var points := PackedVector3Array()
		for surface in prop.mesh.get_surface_count():
			points.append_array(prop.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
		var lib := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("",lib)
		var clearance := Clearance.new(body,rig)
		var fingers := measure_fingers(body,rig)
		for label: String in GESTURES:
			assert(lib.add_animation(label,build_gesture(player,rig,label))==OK)
			fit_clip(player,rig,grip,staff,points,clearance,label)
			close_grip(player,rig,staff,fingers,label)
		Exact.check_earlier_keys(player,source)
		player.stop()
		var out := PackedScene.new()
		assert(out.pack(model)==OK)
		var output := ART_DIR + "bone-magi-distinct-actions-%s.scn" % treatment
		assert(ResourceSaver.save(out, output, ResourceSaver.FLAG_COMPRESS) == OK)
		treatments[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
		model.free()
		print("BONE MAGI ",treatment,": four fitted staff actions, original keys kept")
	var receipt := FileAccess.open(ART_DIR + "bone-magi-distinct-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path), "scenes": treatments}))
	receipt.close()
	quit()

func build_gesture(player: AnimationPlayer, rig: Skeleton3D, label: String) -> Animation:
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	clip.length=0.72 if label=="StaffRaise" else 0.48
	clip.loop_mode=Animation.LOOP_NONE
	for track in clip.get_track_count():
		for key in range(clip.track_get_key_count(track)-1,0,-1):
			clip.track_remove_key(track,key)
	var tracks := {}
	for name: String in ["bip01 spine1","bip01 head","bip01 r upperarm","bip01 r forearm","bip01 l upperarm"]:
		var joint := rig.find_bone(name)
		assert(joint>=0)
		var track := channel(clip,joint_path(player,rig,joint),Animation.TYPE_ROTATION_3D)
		clear_keys(clip,track)
		tracks[name]=track
	player.stop()
	player.play("Idle",0.0)
	player.advance(0.0)
	var basis := rig.global_basis.inverse()
	for index in 81:
		var phase := float(index)/80.0
		rig.reset_bone_poses()
		player.seek(0.0,true)
		rig.force_update_all_bone_transforms()
		var pulse := gesture_strength(phase)
		var release := smoothstep(0.21,0.56,phase)*(1.0-smoothstep(0.69,1.0,phase))
		var pitch: float = {"StaffPush":0.17*release,"StaffSlash":0.14*pulse,
			"StaffRecoil":-0.42*pulse,"StaffRaise":-0.19*pulse}[label]
		var arm: float = {"StaffPush":-0.94*release,"StaffSlash":-0.45*pulse-0.61*release,
			"StaffRecoil":0.35*pulse,"StaffRaise":-1.37*pulse}[label]
		rotate_joint(rig,rig.find_bone("bip01 spine1"),Quaternion((basis*Vector3.RIGHT).normalized(),pitch))
		rotate_joint(rig,rig.find_bone("bip01 spine1"),Quaternion((basis*Vector3.UP).normalized(),
			0.35*release if label=="StaffSlash" else -0.09*pulse))
		rotate_joint(rig,rig.find_bone("bip01 head"),Quaternion((basis*Vector3.RIGHT).normalized(),pitch*0.37))
		rotate_joint(rig,rig.find_bone("bip01 r upperarm"),Quaternion((basis*Vector3.RIGHT).normalized(),arm))
		rotate_joint(rig,rig.find_bone("bip01 r forearm"),Quaternion((basis*Vector3.RIGHT).normalized(),-0.37*pulse))
		rotate_joint(rig,rig.find_bone("bip01 l upperarm"),Quaternion((basis*Vector3.RIGHT).normalized(),-0.23*release))
		for name: String in tracks:
			clip.rotation_track_insert_key(tracks[name],phase*clip.length,rig.get_bone_pose_rotation(rig.find_bone(name)))
	return clip

func staff_direction(rig: Skeleton3D, socket: Transform3D, label: String, phase: float) -> Vector3:
	if label not in GESTURES:
		return super.staff_direction(rig,socket,label,phase)
	var upright := Vector3(-0.24,1.0,0.36).normalized()
	var direction: Vector3 = {"StaffPush":Vector3(-0.18,0.19,0.96),
		"StaffSlash":Vector3(-0.68,0.19,0.67),"StaffRecoil":Vector3(-0.49,0.73,-0.45),
		"StaffRaise":Vector3(-0.21,0.98,-0.13)}[label]
	return upright.slerp(direction.normalized(),gesture_strength(phase))
