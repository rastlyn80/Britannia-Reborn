extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const SERIAL := 0x4100
const FORMS := {
	28: {"clip": "AbdomenShift", "support": ["bone06", "bone10", "bone14", "bone22", "bone26", "bone30", "bone34"],
		"moving": "bone18", "minimum_travel": 0.15},
	39: {"clip": "WingSettle", "support": ["bip01 l toe0", "bip01 r toe0"],
		"moving": "mongbat l wingfinger1b", "minimum_travel": 0.06, "alpha": "mongbats_mongbat-original-albedo.png"},
}

func forms() -> Dictionary:
	return FORMS

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var active := "--active" in OS.get_cmdline_user_args()
	var checked_routes := 0
	for body: int in forms():
		var base := Registry.entry(body)
		var trial := base.duplicate(true)
		var base_assets: Dictionary = base.get("classic_gesture_base_assets", {})
		var recipe: Dictionary = forms()[body]
		var clip: String = recipe.clip
		var alpha: String = recipe.get("alpha", "")
		var routes: Dictionary = recipe.get("actions", {11: clip})
		if not active:
			trial.assets = {}
			trial.classic_action_categories = base.get("classic_action_categories", {}).duplicate()
			for slot: int in routes:
				trial.classic_action_categories[str(slot)] = routes[slot]
			if not alpha.is_empty():
				trial.source_alpha_texture = alpha
			if recipe.has("presentation_script"):
				trial.presentation_script = recipe.presentation_script
		else:
			for slot: int in routes:
				assert(base.classic_action_categories[str(slot)] == routes[slot])
		for treatment in ["original", "rounded", "modern"]:
			var path := "res://local-art/creatures/mul-gesture-%d-%s.scn" % [body, treatment]
			if active:
				var batch: String = base.get("classic_gesture_batch", "")
				if body in [28, 39] and batch == "spider_mongbat_actions":
					var retained := "res://local-art/creatures/mongbat-fidgets-%s.scn" % treatment if body == 39 else path
					assert(base_assets[treatment] == retained)
					path = base.assets[treatment]
				elif body == 39 and batch == "mongbat_fidgets":
					assert(base_assets[treatment] == path)
					path = base.assets[treatment]
				elif body == 74 and batch == "earth_gazer_imp_actions":
					assert(base_assets[treatment] == path)
					path = base.assets[treatment]
				assert(base.assets[treatment] == path and base.authored_action_scene_sha256[treatment] == FileAccess.get_sha256(path))
			else:
				trial.assets[treatment] = path
		if not active:
			Registry.entries[body] = trial
		game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0x8035}
		for treatment in ["original", "rounded", "modern"]:
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.apply_identity(body, 0x8035)
			var source_path: String = base_assets.get(treatment, Registry.asset_path(base, treatment))
			check_tracks(actor.animator, source_path)
			for slot: int in routes:
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(SERIAL, 4))
				packet.append_array(PackedByteArray([0, slot, 0, 5, 0, 1, 1, 0, 0]))
				game._handle(packet)
				assert(actor.receive_action(game.last_mobile_actions[SERIAL]))
				assert(actor.current_clip == routes[slot] and actor.native_hue == 0x8035)
				checked_routes += 1
			if not alpha.is_empty():
				check_source_alpha(actor, treatment, alpha)
			check_identity_material(actor, treatment)
			if not check_motion(actor, body, treatment):
				quit(1)
				return
			actor.queue_free()
			await process_frame
		for hue in [0, recipe.get("native_hue", 53), 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse != null and corpse.get_meta("static_cadaver"))
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.get_meta("death_clip") == "Death" and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			corpse.free()
		Registry.entries[body] = base
	game.free()
	print("CLASSIC GESTURES: ", checked_routes, " decoded routes and static corpse hue checks")
	quit()

func check_identity_material(_actor: Node3D, _treatment: String) -> void:
	pass

func check_tracks(player: AnimationPlayer, source_path: String) -> void:
	var base := (load(source_path) as PackedScene).instantiate()
	var original := base.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for name in original.get_animation_list():
		var before := original.get_animation(name)
		var after := player.get_animation(name)
		assert(before.length == after.length and before.get_track_count() == after.get_track_count())
		for track in before.get_track_count():
			assert(before.track_get_path(track) == after.track_get_path(track))
			assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track))
	base.free()

func check_source_alpha(actor: Node3D, treatment: String, texture: String) -> void:
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var material := mesh.get_surface_override_material(0)
	if treatment == "modern":
		assert(material is ShaderMaterial and material.shader.resource_path.ends_with("CreatureCutoutSurface.gdshader"))
		var alpha: Texture2D = material.get_shader_parameter("source_alpha_texture")
		assert(alpha.resource_path.get_file() == texture)
	else:
		assert(material is StandardMaterial3D and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR)

func check_motion(actor: Node3D, body: int, treatment: String) -> bool:
	var recipe: Dictionary = forms()[body]
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var planted: Array[int] = []
	for joint: String in recipe.support:
		planted.append(rig.find_bone(joint))
	var moving := rig.find_bone(recipe.moving)
	assert(moving >= 0 and not planted.has(-1))
	var start: Array[Vector3] = []
	var moving_start := Vector3.ZERO
	var drift := 0.0
	var travel := 0.0
	var minimum := INF
	var start_floor := 0.0
	var lowest_sample := 0
	var root_pose := actor.global_transform
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var idle_floor := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
	player.stop()
	player.play(recipe.clip, 0.0)
	player.advance(0.0)
	for sample in 101:
		player.seek(player.get_animation(recipe.clip).length * float(sample) / 100.0, true)
		rig.force_update_all_bone_transforms()
		var point := rig.to_global(rig.get_bone_global_pose(moving).origin)
		if sample == 0:
			moving_start = point
			for joint in planted:
				start.append(rig.to_global(rig.get_bone_global_pose(joint).origin))
		for i in planted.size():
			drift = maxf(drift, rig.to_global(rig.get_bone_global_pose(planted[i]).origin).distance_to(start[i]))
		travel = maxf(travel, point.distance_to(moving_start))
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		if sample == 0:
			start_floor = gap
		if gap < minimum:
			minimum = gap
			lowest_sample = sample
		if not actor.global_transform.is_equal_approx(root_pose) or sample == 100 and point.distance_to(moving_start) > 0.001:
			return false
	print(body, " ", treatment, " idle, start, min, lowest sample, planted drift and moving-joint travel ",
		[idle_floor, start_floor, minimum, lowest_sample, drift, travel])
	return (minimum > idle_floor - 0.003 and drift < 0.001
		and travel >= recipe.minimum_travel and travel <= recipe.get("maximum_travel", INF))
