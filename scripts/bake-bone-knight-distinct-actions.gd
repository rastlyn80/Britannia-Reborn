extends "res://../scripts/bake-bone-knight-cyclops.gd"

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const GESTURES := ["ShieldSideCut", "ShieldOvercut", "ShieldDuck", "BladeParry", "BladeSalute"]

func run() -> void:
	var treatments := {}
	var base := Registry.entry(57)
	for treatment: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(base, treatment)
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var clearance := BladeClearance.new(mesh, rig)
		var props: Array[Dictionary] = []
		for label: String in ["Scimitar", "WoodenShield"]:
			var prop := rig.get_node(label) as MeshInstance3D
			var bone := rig.find_bone(label.to_lower())
			var points := PackedVector3Array()
			for surface in prop.mesh.get_surface_count():
				points.append_array(prop.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
			props.append({"label": label, "grip": rig.get_bone_parent(bone), "bone": bone, "points": points})
		var lib := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", lib)
		for clip: String in GESTURES:
			assert(lib.add_animation(clip, author(player, rig, clip)) == OK)
			fit_clip(player, rig, clip, props, clearance)
		Exact.check_earlier_keys(player, source)
		player.stop()
		var output := PackedScene.new()
		assert(output.pack(model) == OK)
		assert(ResourceSaver.save(output, ART_DIR + "bone-knight-distinct-actions-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		treatments[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(ART_DIR + "bone-knight-distinct-actions-%s.scn" % treatment)}
		model.free()
		print("BONE KNIGHT PREVIEW ", treatment, ": five new motions, preserved prop and actor keys")
	var receipt := FileAccess.open("res://local-art/creatures/bone-knight-distinct-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path), "scenes": treatments}))
	receipt.close()
	quit()

func author(player: AnimationPlayer, rig: Skeleton3D, name: String) -> Animation:
	var motion := player.get_animation("Idle").duplicate(true) as Animation
	motion.length = 0.72 if name == "BladeSalute" else 0.47
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		for key in range(motion.track_get_key_count(track) - 1, 0, -1):
			motion.track_remove_key(track, key)
	var tracks := {}
	var path := player.get_node(player.root_node).get_path_to(rig)
	for label: String in BONES.slice(0, 9):
		tracks[label] = channel(motion, NodePath("%s:%s" % [path,label]), Animation.TYPE_ROTATION_3D)
		if motion.track_get_key_count(tracks[label]) > 0:
			motion.track_remove_key(tracks[label], 0)
	player.play("Idle", 0.0)
	player.advance(0.0)
	var inv := rig.global_basis.inverse()
	for frame in 81:
		var phase := float(frame) / 80.0
		var lift := smoothstep(0.02, 0.33, phase) * (1.0 - smoothstep(0.52, 1.0, phase))
		var follow := smoothstep(0.25, 0.61, phase) * (1.0 - smoothstep(0.74, 1.0, phase))
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		var yaw: float = {"ShieldSideCut": -0.27*lift + 0.40*follow, "ShieldOvercut": 0.19*lift - 0.22*follow,
			"ShieldDuck": -0.31*lift, "BladeParry": 0.28*lift, "BladeSalute": 0.08*lift}[name]
		var shoulder: float = {"ShieldSideCut": 0.28*lift - 1.05*follow, "ShieldOvercut": -1.38*lift - 0.45*follow,
			"ShieldDuck": 0.11*lift - 0.44*follow, "BladeParry": -1.10*lift, "BladeSalute": -1.46*lift}[name]
		var elbow: float = {"ShieldSideCut": -0.16*lift - 0.12*follow, "ShieldOvercut": -0.65*lift + 0.15*follow,
			"ShieldDuck": -0.58*lift, "BladeParry": -0.47*lift, "BladeSalute": -0.33*lift}[name]
		rotate_joint(rig, rig.find_bone("bip01 spine1"), Quaternion((inv*Vector3.UP).normalized(), yaw))
		rotate_joint(rig, rig.find_bone("bip01 spine1"), Quaternion((inv*Vector3.RIGHT).normalized(), 0.29*lift if name=="ShieldDuck" else 0.0))
		rotate_joint(rig, rig.find_bone("bip01 r upperarm"), Quaternion((inv*Vector3.RIGHT).normalized(), shoulder))
		rotate_joint(rig, rig.find_bone("bip01 r forearm"), Quaternion((inv*Vector3.RIGHT).normalized(), elbow))
		rotate_joint(rig, rig.find_bone("bip01 l upperarm"), Quaternion((inv*Vector3.RIGHT).normalized(), -0.25*lift))
		for label: String in tracks:
			motion.rotation_track_insert_key(tracks[label], phase * motion.length, rig.get_bone_pose_rotation(rig.find_bone(label)))
	return motion

func orientation(label: String, clip: String, phase: float) -> Basis:
	if label != "Scimitar":
		return super.orientation(label, clip, phase)
	var start := Vector3(-0.32, 0.41, 0.86).normalized()
	var wind: Vector3 = {"ShieldSideCut": Vector3(-0.81,0.14,-0.54), "ShieldOvercut": Vector3(-0.38,0.88,-0.23),
		"ShieldDuck": Vector3(-0.74,0.33,0.58), "BladeParry": Vector3(-0.65,0.65,-0.39), "BladeSalute": Vector3(-0.38,0.91,-0.18)}[clip]
	var finish: Vector3 = {"ShieldSideCut": Vector3(-0.35,0.10,0.93), "ShieldOvercut": Vector3(-0.20,-0.20,0.96),
		"ShieldDuck": Vector3(-0.68,0.44,0.57), "BladeParry": Vector3(-0.72,0.43,0.54), "BladeSalute": Vector3(-0.51,0.52,0.68)}[clip]
	var raise := smoothstep(0.04, 0.31, phase) * (1.0-smoothstep(0.57, 1.0, phase))
	var swing :=  smoothstep(0.28, 0.64, phase) * (1.0-smoothstep(0.74, 1.0, phase))
	return Basis(Quaternion(Vector3.UP, start.slerp(wind.normalized(),raise).slerp(finish.normalized(),swing).normalized()))
