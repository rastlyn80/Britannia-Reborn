extends SceneTree
## Classic group 11: rooted Reaper bend and a rephased source Harpy flight cycle.

const FORMS := {47: "flails_reaper", 30: "harpies_harpy"}
const BEND := [0.0, 0.58, 1.0, 0.83, 0.37, 0.0]
const BEND_TIMES := [0.0, 0.14, 0.31, 0.52, 0.70, 0.88]
const HARPY_PHASE := 0.42
const HARPY_SEAM := 0.04

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	for body: int in FORMS:
		for treatment in ["original", "rounded", "modern"]:
			if not bake(body, treatment):
				quit(1)
				return
	quit()

func bake(body: int, treatment: String) -> bool:
	var path := "res://local-art/creatures/%s-%s.gltf" % [FORMS[body], treatment]
	var model := (load(path) as PackedScene).instantiate()
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var library := player.get_animation_library("")
	var name := "Wingbeat" if body == 30 else "TrunkBend"
	var motion := wingbeat(library.get_animation("Fly")) if body == 30 else trunk_bend(player, rig)
	if body == 47 and treatment != "modern":
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = 0.12
			mesh.mesh.surface_set_material(surface, material)
	var saved := false
	if library.add_animation(name, motion) == OK:
		var scene := PackedScene.new()
		var output := "res://local-art/creatures/mul-gesture-%d-%s.scn" % [body, treatment]
		saved = scene.pack(model) == OK and ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK
	model.free()
	print("CLASSIC ", body, " ", treatment, ": ", name, ", ", motion.get_track_count(), " tracks")
	return saved

func wingbeat(source: Animation) -> Animation:
	var motion := Animation.new()
	motion.length = source.length + HARPY_SEAM
	var source_start := source.length * HARPY_PHASE
	var intervals := ceili(motion.length * 240.0)
	for track in source.get_track_count():
		var type := source.track_get_type(track)
		assert(type == Animation.TYPE_POSITION_3D or type == Animation.TYPE_ROTATION_3D)
		var destination := motion.add_track(type)
		motion.track_set_path(destination, source.track_get_path(track))
		for index in intervals + 1:
			var time := motion.length * float(index) / intervals
			var shifted := time + source_start
			if shifted <= source.length:
				copy_pose(source, track, motion, destination, time, shifted)
			elif shifted >= source.length + HARPY_SEAM:
				copy_pose(source, track, motion, destination, time, shifted - motion.length)
			else:
				var blend := smoothstep(source.length, source.length + HARPY_SEAM, shifted)
				if type == Animation.TYPE_POSITION_3D:
					var a := source.position_track_interpolate(track, source.length)
					var b := source.position_track_interpolate(track, 0.0)
					motion.position_track_insert_key(destination, time, a.lerp(b, blend))
				else:
					var a := source.rotation_track_interpolate(track, source.length)
					var b := source.rotation_track_interpolate(track, 0.0)
					motion.rotation_track_insert_key(destination, time, a.slerp(b, blend))
	return motion

func copy_pose(source: Animation, track: int, motion: Animation, destination: int, time: float, sample: float) -> void:
	if source.track_get_type(track) == Animation.TYPE_POSITION_3D:
		motion.position_track_insert_key(destination, time, source.position_track_interpolate(track, sample))
	else:
		motion.rotation_track_insert_key(destination, time, source.rotation_track_interpolate(track, sample))

func trunk_bend(player: AnimationPlayer, rig: Skeleton3D) -> Animation:
	var motion := player.get_animation("Idle").duplicate(true) as Animation
	motion.length = BEND_TIMES[-1]
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		var value: Variant = motion.track_get_key_value(track, 0)
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		motion.track_insert_key(track, 0.0, value)
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var names := ["bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 r upperarm", "bip01 l upperarm"]
	var pitch := [0.18, 0.22, 0.13, -0.10, 0.12]
	var tracks: Array[int] = []
	var idle: Array[Quaternion] = []
	for name: String in names:
		var bone := rig.find_bone(name)
		assert(bone >= 0)
		var path := NodePath("%s:%s" % [rig_path, name])
		var track := motion.find_track(path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(track, path)
		tracks.append(track)
		idle.append(rig.get_bone_pose_rotation(bone))
	var right := (rig.global_basis.inverse() * Vector3.RIGHT).normalized()
	for sample in 107:
		var time := motion.length * float(sample) / 106.0
		var phase := 0
		while phase < BEND_TIMES.size() - 2 and time > BEND_TIMES[phase + 1]:
			phase += 1
		var amount := lerpf(BEND[phase], BEND[phase + 1], smoothstep(BEND_TIMES[phase], BEND_TIMES[phase + 1], time))
		for i in names.size():
			rig.set_bone_pose_rotation(rig.find_bone(names[i]), idle[i])
		for i in names.size():
			rig.force_update_all_bone_transforms()
			var bone := rig.find_bone(names[i])
			var pose := rig.get_bone_global_pose(bone)
			pose.basis = Basis(Quaternion(right, pitch[i] * amount)) * pose.basis
			rig.set_bone_global_pose(bone, pose)
			motion.rotation_track_insert_key(tracks[i], time, rig.get_bone_pose_rotation(bone))
	player.stop()
	return motion
