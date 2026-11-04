extends SceneTree

const BODY := 831
const SERIAL := 0x4100
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var row := Registry.entry(BODY).duplicate(true)
	assert(row.kind == "birds_parrot")
	var active := "--active" in OS.get_cmdline_user_args()
	var original_assets: Dictionary = row.get("classic_gesture_base_assets", row.assets).duplicate(true)
	for treatment in ["original", "rounded", "modern"]:
		var path := "res://local-art/creatures/parrot-831-flight-trial-%s.scn" % treatment
		if active:
			assert(row.assets[treatment] == path and row.authored_action_scene_sha256[treatment] == FileAccess.get_sha256(path))
		else:
			row.assets[treatment] = path
	if active:
		assert(row.classic_action_categories["19"] == "Fly")
	else:
		Registry.entries[BODY] = row
	var session := Game.new()
	root.add_child(session)
	session.set_process(false)
	session.entities[SERIAL] = {"serial": SERIAL, "body": BODY, "hue": 0x8035}
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(SERIAL, 4))
	packet.append_array(PackedByteArray([0, 19, 0, 8, 0, 1, 1, 0, 0]))
	session._handle(packet)
	for treatment in ["original", "rounded", "modern"]:
		var original := (load(original_assets[treatment]) as PackedScene).instantiate()
		var source := original.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var actor := Registry.create(BODY)
		actor.treatment = treatment
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.apply_identity(BODY, 0x8035)
		assert(not source.has_animation("Fly"))
		for clip_name in source.get_animation_list():
			var before := source.get_animation(clip_name)
			var after: Animation = actor.animator.get_animation(clip_name)
			assert(after.length == before.length and after.get_track_count() == before.get_track_count())
			for track in before.get_track_count():
				assert(after.track_get_path(track) == before.track_get_path(track))
				assert(after.get("tracks/%d/keys" % track) == before.get("tracks/%d/keys" % track))
		original.free()
		assert(actor.receive_action(session.last_mobile_actions[SERIAL]))
		assert(actor.current_clip == "Fly" and not actor.contact.enabled and actor.native_hue == 0x8035)
		if not check_cycle(actor, treatment):
			push_error("Parrot flight exceeds clearance or continuity tolerances")
			quit(1)
			return
		actor._process(actor.action_remaining + 0.001)
		actor.play_gait(false, 0.0)
		assert(actor.current_clip == "Idle" and actor.contact.enabled and actor.animator.assigned_animation == "Idle")
		actor.free()
	for hue in [0, 53, 0x8035]:
		var corpse := Corpses.build(BODY, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver"))
		assert(corpse.get_meta("corpse_body") == BODY and corpse.get_meta("graphic_id") == 0x2006)
		assert(corpse.get_meta("native_hue") == hue and corpse.get_meta("death_clip") == "Death")
		assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
	session.free()
	print("Parrot 831: three decoded flight-to-idle routes and three static corpse hues")
	quit()

func check_cycle(actor: Node3D, treatment: String) -> bool:
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var data := Ground.skin_points(mesh, rig)
	var left := rig.find_bone("bip01 l finger01")
	var right := rig.find_bone("bip01 r finger01")
	assert(left >= 0 and right >= 0)
	var first_left := Vector3.ZERO
	var first_right := Vector3.ZERO
	var lowest := INF
	var slope_gap := INF
	var wing_span := INF
	var wing_drop := 0.0
	var root_pose := actor.global_transform
	var slopes := [Vector3(-0.14, 1, 0).normalized(), Vector3(0.14, 1, 0).normalized(),
		Vector3(0, 1, -0.14).normalized(), Vector3(0, 1, 0.14).normalized()]
	player.play("Fly", 0.0, 1.0)
	player.advance(0.0)
	for sample in 97:
		player.seek(player.get_animation("Fly").length * float(sample) / 96.0, true)
		rig.force_update_all_bone_transforms()
		var left_tip := rig.to_global(rig.get_bone_global_pose(left).origin)
		var right_tip := rig.to_global(rig.get_bone_global_pose(right).origin)
		if sample == 0:
			first_left = left_tip
			first_right = right_tip
		wing_span = minf(wing_span, left_tip.distance_to(right_tip))
		wing_drop = maxf(wing_drop, minf(first_left.y - left_tip.y, first_right.y - right_tip.y))
		lowest = minf(lowest, Ground.minimum_plane_gap(data, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		for normal: Vector3 in slopes:
			slope_gap = minf(slope_gap, Ground.minimum_plane_gap(data, rig, rig.global_transform, Vector3.ZERO, normal))
		if not actor.global_transform.is_equal_approx(root_pose):
			return false
		if sample == 96 and (first_left.distance_to(left_tip) >= 0.001 or first_right.distance_to(right_tip) >= 0.001):
			return false
	print("Parrot 831 ", treatment, " 97 poses: floor, slope, minimum tip span, wing drop ",
		[lowest, slope_gap, wing_span, wing_drop])
	return lowest >= 0.075 and slope_gap >= 0.04 and wing_span > 0.06 and wing_drop > 0.65
