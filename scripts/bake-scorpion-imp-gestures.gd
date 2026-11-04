extends SceneTree

const ART := "res://local-art/creatures/"
const FORMS := {48: "scorpions_giant", 74: "imps_imp"}
const CLAW_TIMES := [0.0, 0.25, 0.68, 0.83, 1.0]
const CLAW_PHASES := [0.0, 0.26, 0.51, 0.58, 1.0]
const WINGS := ["imp_l_wing 01", "imp_r_wing 01"]

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	for body: int in FORMS:
		for treatment: String in ["original", "rounded", "modern"]:
			var stem: String = FORMS[body]
			var path := ART + stem + "-" + treatment + ".gltf"
			var model := (load(path) as PackedScene).instantiate()
			root.add_child(model)
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var library := player.get_animation_library("")
			if body == 48:
				assert(library.add_animation("ClawDraw", claw_draw(library.get_animation("Fidget"))) == OK)
			else:
				var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
				var twitch := wing_twitch(player, rig)
				assert(library.add_animation("WingTwitch", twitch) == OK)
				assert(library.add_animation("Fidget2", twitch.duplicate(true)) == OK)
			if treatment != "modern":
				var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
				for surface in mesh.mesh.get_surface_count():
					var material := mesh.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
					material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					material.alpha_scissor_threshold = 0.12
					mesh.mesh.surface_set_material(surface, material)
			player.stop()
			var scene := PackedScene.new()
			assert(scene.pack(model) == OK)
			var output := ART + "mul-gesture-%d-%s.scn" % [body, treatment]
			assert(ResourceSaver.save(scene, output, ResourceSaver.FLAG_COMPRESS) == OK)
			model.free()
			print("CLASSIC ", body, " ", treatment, ": ", "ClawDraw" if body == 48 else "WingTwitch")
	quit()

func claw_draw(source: Animation) -> Animation:
	var motion := Animation.new()
	motion.length = 1.08
	for track in source.get_track_count():
		var path := source.track_get_path(track)
		var type := source.track_get_type(track)
		var destination := motion.add_track(type)
		motion.track_set_path(destination, path)
		var bone := str(path.get_subname(0)) if path.get_subname_count() > 0 else ""
		var is_claw := bone.ends_with("arm") or bone.ends_with("hand") or bone.contains("finger")
		var is_tail := bone.begins_with("bip01 tail")
		var segment := 0
		for i in 131:
			var phase := float(i) / 130.0
			var donor_phase := minf(phase / 0.79, 1.0) if is_tail else 0.0
			if is_claw:
				while segment < CLAW_TIMES.size() - 2 and phase > CLAW_TIMES[segment + 1]:
					segment += 1
				var blend := smoothstep(CLAW_TIMES[segment], CLAW_TIMES[segment + 1], phase)
				donor_phase = lerpf(CLAW_PHASES[segment], CLAW_PHASES[segment + 1], blend)
			var sample := donor_phase * source.length
			var time := phase * motion.length
			var settle := smoothstep(0.91, 1.0, phase)
			match type:
				Animation.TYPE_POSITION_3D:
					var start := source.position_track_interpolate(track, 0.0)
					var pose := source.position_track_interpolate(track, sample)
					motion.position_track_insert_key(destination, time, pose.lerp(start, settle))
				Animation.TYPE_ROTATION_3D:
					var start := source.rotation_track_interpolate(track, 0.0)
					var pose := source.rotation_track_interpolate(track, sample)
					motion.rotation_track_insert_key(destination, time, pose.slerp(start, settle))
				_:
					assert(false, "Unexpected Scorpion animation channel")
	return motion

func wing_twitch(player: AnimationPlayer, rig: Skeleton3D) -> Animation:
	var motion := player.get_animation("Idle").duplicate(true) as Animation
	motion.length = 0.65
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
	var path := player.get_node(player.root_node).get_path_to(rig)
	var up := (rig.global_basis.inverse() * Vector3.UP).normalized()
	var right := (rig.global_basis.inverse() * Vector3.RIGHT).normalized()
	for i in WINGS.size():
		var bone := rig.find_bone(WINGS[i])
		assert(bone >= 0)
		var key := NodePath("%s:%s" % [path, WINGS[i]])
		var track := motion.find_track(key, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(track, key)
		var local := rig.get_bone_pose_rotation(bone)
		var reference := rig.get_bone_global_pose(bone)
		var side := 1.0 if i == 0 else -1.0
		for sample in 79:
			var phase := float(sample) / 78.0
			var strength := pow(sin(PI * phase), 2.0)
			var pose := reference
			pose.basis = Basis(Quaternion(up, side * 0.12 * strength) * Quaternion(right, 0.045 * strength)) * reference.basis
			rig.set_bone_global_pose(bone, pose)
			motion.rotation_track_insert_key(track, phase * motion.length, rig.get_bone_pose_rotation(bone))
		rig.set_bone_pose_rotation(bone, local)
		rig.force_update_all_bone_transforms()
	return motion
