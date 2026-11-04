extends "res://../scripts/test-spider-mongbat-gestures.gd"

const HARPY_VISUAL := "res://Presentation/SourceHarpyWingbeatVisual.gd"
const GESTURES := {30: "Wingbeat", 47: "TrunkBend"}

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var active := "--active" in OS.get_cmdline_user_args()
	for body: int in GESTURES:
		var base := Registry.entry(body)
		var trial := base.duplicate(true)
		var clip: String = GESTURES[body]
		if not active:
			trial.assets = {}
			trial.classic_action_categories = base.get("classic_action_categories", {}).merged({"11": clip}, true)
			if body == 30:
				trial.presentation_script = HARPY_VISUAL
			else:
				trial.source_alpha_texture = "flails_reaper-original-albedo.png"
		else:
			assert(base.classic_action_categories["11"] == clip)
		for treatment in ["original", "rounded", "modern"]:
			var path := "res://local-art/creatures/mul-gesture-%d-%s.scn" % [body, treatment]
			if active:
				assert(base.assets[treatment] == path and base.authored_action_scene_sha256[treatment] == FileAccess.get_sha256(path))
			else:
				trial.assets[treatment] = path
		if not active:
			Registry.entries[body] = trial
		var packet := PackedByteArray([0x6e])
		packet.append_array(Wire.uint_be(SERIAL, 4))
		packet.append_array(PackedByteArray([0, 11, 0, 5, 0, 1, 1, 0, 0]))
		game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0x8035}
		game._handle(packet)
		for treatment in ["original", "rounded", "modern"]:
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.apply_identity(body, 0x8035)
			var base_assets: Dictionary = base.get("classic_gesture_base_assets", {})
			check_tracks(actor.animator, base_assets.get(treatment, Registry.asset_path(base, treatment)))
			assert(actor.receive_action(game.last_mobile_actions[SERIAL]))
			assert(actor.current_clip == clip and actor.native_hue == 0x8035)
			assert(actor.contact.enabled == (body == 47))
			if body == 47:
				check_branch_alpha(actor, treatment)
			check_gesture(actor, body, treatment)
			actor._process(actor.action_remaining + 0.001)
			actor.play_gait(false, 0.0)
			assert(actor.current_clip == "Idle" and actor.contact.enabled)
			actor.queue_free()
			await process_frame
		for hue in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse != null and corpse.get_meta("static_cadaver"))
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.get_meta("death_clip") == "Death" and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			corpse.free()
		Registry.entries[body] = base
	game.free()
	print("REAPER AND HARPY: six decoded routes and six static corpse hues")
	quit()

func check_branch_alpha(actor: Node3D, treatment: String) -> void:
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var material := mesh.get_surface_override_material(0)
	if treatment == "modern":
		assert(material is ShaderMaterial and material.shader.resource_path.ends_with("CreatureCutoutSurface.gdshader"))
		var alpha: Texture2D = material.get_shader_parameter("source_alpha_texture")
		assert(alpha.resource_path.ends_with("flails_reaper-original-albedo.png"))
	else:
		assert(material is StandardMaterial3D and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)

func check_gesture(actor: Node3D, body: int, treatment: String) -> void:
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var names := ["bip01 pelvis", "bip01 l finger1", "bip01 r finger1"] if body == 30 else ["bip01 pelvis", "bip01 neck"]
	var joints: Array[int] = []
	for joint: String in names:
		joints.append(rig.find_bone(joint))
	assert(not joints.has(-1))
	var start: Array[Vector3] = []
	var wing_lows := Vector2(INF, INF)
	var drift := 0.0
	var travel := 0.0
	var minimum := INF
	var root_pose := actor.global_transform
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	rig.force_update_all_bone_transforms()
	var idle_floor := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
	player.stop()
	player.play(GESTURES[body], 0.0)
	player.advance(0.0)
	for sample in 101:
		player.seek(player.get_animation(GESTURES[body]).length * float(sample) / 100.0, true)
		rig.force_update_all_bone_transforms()
		var points: Array[Vector3] = []
		for joint in joints:
			points.append(rig.to_global(rig.get_bone_global_pose(joint).origin))
		if sample == 0:
			start.assign(points)
		if sample == 100:
			for i in points.size():
				assert(points[i].distance_to(start[i]) < 0.001)
		drift = maxf(drift, points[0].distance_to(start[0]))
		travel = maxf(travel, points[1].distance_to(start[1]))
		if body == 30:
			wing_lows = wing_lows.min(Vector2(points[1].y, points[2].y) - Vector2.ONE * points[0].y)
		minimum = minf(minimum, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		assert(actor.global_transform.is_equal_approx(root_pose))
	print(body, " ", treatment, " idle floor, min floor, pelvis drift, joint travel, relative wing lows ",
		[idle_floor, minimum, drift, travel, wing_lows])
	if body == 30:
		var wing_start := Vector2(start[1].y, start[2].y) - Vector2.ONE * start[0].y
		print("wing start ", wing_start)
		assert(minimum > 0.05 and wing_start.x > 0.7 and wing_start.y > 0.7)
		assert(wing_lows.x < -0.2 and wing_lows.y < -0.2)
	else:
		assert(minimum > idle_floor - 0.003 and drift < 0.001 and travel > 0.2)
