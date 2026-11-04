extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const SERIAL := 0x4100
const PROFILE := {
	730: {"head": "Head", "feet": ["BackFoot.L", "BackFoot.R"], "min_head_rise": 0.15},
	734: {"head": "bip01 head", "feet": ["bip01 l foot", "bip01 r foot", "bip01 l hand", "bip01 r hand"],
		"min_head_rise": 0.025},
}

func _initialize() -> void:
	create_timer(40.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var active := "--active" in OS.get_cmdline_user_args()
	for body: int in PROFILE:
		var registered := Registry.entry(body)
		var candidate := registered.duplicate(true)
		var base_assets: Dictionary = registered.get("classic_gesture_base_assets", registered.assets)
		for treatment in ["original", "rounded", "modern"]:
			var suffix: String = "shared" if body == 730 else treatment
			var path := "res://local-art/creatures/ready-stance-%d-%s.scn" % [body, suffix]
			if active:
				assert(registered.assets[treatment] == path and registered.authored_action_scene_sha256[treatment] == FileAccess.get_sha256(path))
			else:
				candidate.assets[treatment] = path
		if active:
			assert(registered.classic_action_categories["11"] == "ReadyStance" and registered.new_action_categories["14"] == "ReadyStance")
		else:
			candidate.classic_action_categories = candidate.get("classic_action_categories", {}).merged({"11": "ReadyStance"}, true)
			candidate.new_action_categories = candidate.get("new_action_categories", {}).merged({"14": "ReadyStance"}, true)
			Registry.entries[body] = candidate
		game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0x8035}
		for treatment in ["original", "rounded", "modern"]:
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.apply_identity(body, 0x8035)
			check_original_clips(actor.animator, base_assets[treatment])
			for command in [[0x6e, [0, 11, 0, 10, 0, 1, 1, 0, 0]], [0xe2, [0, 14, 0, 0, 0]]]:
				var packet := PackedByteArray([command[0]])
				packet.append_array(Wire.uint_be(SERIAL, 4))
				packet.append_array(PackedByteArray(command[1]))
				game._handle(packet)
				assert(actor.receive_action(game.last_mobile_actions[SERIAL]))
				assert(actor.current_clip == "ReadyStance" and actor.contact.enabled and actor.native_hue == 0x8035)
			if not check_pose(actor, body, treatment):
				quit(1)
				return
			actor.queue_free()
			await process_frame
		for hue in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse != null and corpse.get_meta("static_cadaver"))
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.get_meta("death_clip") == "Death" and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			corpse.free()
		Registry.entries[body] = registered
	game.free()
	print("READY STANCES: 12 decoded routes and six static corpse hues")
	quit()

func check_original_clips(player: AnimationPlayer, path: String) -> void:
	var model := (load(path) as PackedScene).instantiate()
	var source := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for name in source.get_animation_list():
		var before := source.get_animation(name)
		var after := player.get_animation(name)
		assert(before.length == after.length and before.get_track_count() == after.get_track_count())
		for track in before.get_track_count():
			assert(before.track_get_path(track) == after.track_get_path(track))
			assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track))
	model.free()

func check_pose(actor: Node3D, body: int, treatment: String) -> bool:
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var profile: Dictionary = PROFILE[body]
	var head := rig.find_bone(profile.head)
	var feet: Array[int] = []
	for name: String in profile.feet:
		feet.append(rig.find_bone(name))
	assert(head >= 0 and not feet.has(-1))
	var root_pose := actor.global_transform
	player.play("Idle", 0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	var rest_head := rig.to_global(rig.get_bone_global_pose(head).origin)
	var rest_feet: Array[Vector3] = []
	for bone in feet:
		rest_feet.append(rig.to_global(rig.get_bone_global_pose(bone).origin))
	var floor_idle := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
	var slopes := [Vector3(-0.14, 1, 0).normalized(), Vector3(0.14, 1, 0).normalized(),
		Vector3(0, 1, -0.14).normalized(), Vector3(0, 1, 0.14).normalized()]
	var idle_slopes: Array[float] = []
	for normal: Vector3 in slopes:
		idle_slopes.append(Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, normal))
	var worst_floor := INF
	var worst_slope_change := INF
	var lowest_head_rise := INF
	var max_foot_drift := 0.0
	var first_head := Vector3.ZERO
	var head_motion := 0.0
	player.play("ReadyStance", 0.0)
	player.advance(0.0)
	for sample in 121:
		player.seek(float(sample) / 120.0, true)
		rig.force_update_all_bone_transforms()
		var head_point := rig.to_global(rig.get_bone_global_pose(head).origin)
		if sample == 0:
			first_head = head_point
		head_motion = maxf(head_motion, head_point.distance_to(first_head))
		for index in feet.size():
			var point := rig.to_global(rig.get_bone_global_pose(feet[index]).origin)
			max_foot_drift = maxf(max_foot_drift, point.distance_to(rest_feet[index]))
		worst_floor = minf(worst_floor, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		for slope in slopes.size():
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, slopes[slope])
			worst_slope_change = minf(worst_slope_change, gap - idle_slopes[slope])
		lowest_head_rise = minf(lowest_head_rise, head_point.y - rest_head.y)
		if not actor.global_transform.is_equal_approx(root_pose) or sample == 120 and head_point.distance_to(first_head) > 0.001:
			return false
	print(body, " ", treatment, " idle floor, ready floor, slope delta, feet, head lift, head motion ",
		[floor_idle, worst_floor, worst_slope_change, max_foot_drift, lowest_head_rise, head_motion])
	return (worst_floor > floor_idle - 0.003 and worst_slope_change > -0.004 and max_foot_drift < 0.001
		and lowest_head_rise >= profile.min_head_rise and head_motion > 0.003)
