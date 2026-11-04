extends SceneTree

const BODY := 21
const SERIAL := 0x4100
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var baseline := Registry.entry(BODY)
	assert(baseline.kind == "serpents_snake_giant")
	var active := "--active" in OS.get_cmdline_user_args()
	var candidate := baseline.duplicate(true)
	candidate.assets = {}
	for treatment in ["original", "rounded", "modern"]:
		var path := "res://local-art/creatures/giant-serpent-21-pillage-%s.scn" % treatment
		if active:
			assert(baseline.assets[treatment] == path and baseline.authored_action_scene_sha256[treatment] == FileAccess.get_sha256(path))
		else:
			candidate.assets[treatment] = path
	if active:
		assert(baseline.classic_action_categories["11"] == "Pillage")
	else:
		Registry.entries[BODY] = candidate
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[SERIAL] = {"serial": SERIAL, "body": BODY, "hue": 0x8035}
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(SERIAL, 4))
	packet.append_array(PackedByteArray([0, 11, 0, 5, 0, 1, 1, 0, 0]))
	game._handle(packet)
	for treatment in ["original", "rounded", "modern"]:
		var actor := Registry.create(BODY)
		actor.treatment = treatment
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.apply_identity(BODY, 0x8035)
		assert(actor.receive_action(game.last_mobile_actions[SERIAL]))
		assert(actor.current_clip == "Pillage" and actor.native_hue == 0x8035)
		var player: AnimationPlayer = actor.animator
		var base_assets: Dictionary = baseline.get("classic_gesture_base_assets", {})
		var source_path := str(base_assets.get(treatment, Registry.asset_path(baseline, treatment)))
		var old_scene := (load(source_path) as PackedScene).instantiate()
		var old_player := old_scene.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		for name in old_player.get_animation_list():
			compare_tracks(old_player.get_animation(name), player.get_animation(name), false)
		old_scene.free()
		var donor := (load("res://local-art/creatures/serpents_snake_giant_silver-%s.gltf" % treatment) as PackedScene).instantiate()
		var donor_player := donor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		compare_tracks(donor_player.get_animation("Pillage"), player.get_animation("Pillage"), true)
		donor.free()
		if not check_motion(actor, treatment):
			quit(1)
			return
		actor.queue_free()
		await process_frame
	for hue in [0, 53, 0x8035]:
		var corpse := Corpses.build(BODY, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver"))
		assert(corpse.get_meta("corpse_body") == BODY and corpse.get_meta("native_hue") == hue)
		assert(corpse.get_meta("death_clip") == "Death" and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
	game.free()
	print("GIANT SERPENT 21: three decoded routes, all original motion keys, three static corpse hues")
	quit()

func compare_tracks(before: Animation, after: Animation, bones_only: bool) -> void:
	assert(before.length == after.length and before.get_track_count() == after.get_track_count())
	for track in before.get_track_count():
		var path := before.track_get_path(track)
		if bones_only and path.get_subname_count() == 0:
			continue
		var target := after.find_track(path, before.track_get_type(track))
		assert(target >= 0)
		assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % target))

func check_motion(actor: Node3D, treatment: String) -> bool:
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var head := rig.find_bone("bip01 head")
	assert(head >= 0)
	var original_root := actor.global_transform
	var first := Vector3.ZERO
	var head_travel := 0.0
	var maximum_floor_error := 0.0
	var worst_sample := 0
	var floor_range := Vector2(INF, -INF)
	player.stop()
	player.play("Pillage", 0.0)
	player.advance(0.0)
	for sample in 191:
		player.seek(player.get_animation("Pillage").length * float(sample) / 190.0, true)
		rig.force_update_all_bone_transforms()
		var point := rig.to_global(rig.get_bone_global_pose(head).origin)
		if sample == 0:
			first = point
		head_travel = maxf(head_travel, point.distance_to(first))
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		floor_range = Vector2(minf(floor_range.x, gap), maxf(floor_range.y, gap))
		if absf(gap) > maximum_floor_error:
			maximum_floor_error = absf(gap)
			worst_sample = sample
		if not actor.global_transform.is_equal_approx(original_root):
			return false
	print("Giant Serpent ", treatment, " floor range, worst sample and head travel ", [floor_range, worst_sample, head_travel])
	return maximum_floor_error < 0.003 and head_travel > 0.10
