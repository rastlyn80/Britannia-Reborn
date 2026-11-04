extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const SkinBounds := preload("res://Presentation/SkinGeometry.gd")
const CLIPS := {1: "FaceWipe", 3: "ArmsRaise", 50: "Reach", 42: "Hunch"}
const SERIAL := 0x4100

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var active := "--active" in OS.get_cmdline_user_args()
	var ratman := "--ratman" in OS.get_cmdline_user_args()
	var bodies := [42] if ratman else [1, 3, 50]
	var historical_skeleton := Registry.entry(56).duplicate(true)
	var ratman_sibling := Registry.entry(142).duplicate(true)
	for body: int in bodies:
		for treatment in ["original", "rounded", "modern"]:
			if not check_route(game, body, treatment, active):
				quit(1)
				return
	assert(Registry.entry(56) == historical_skeleton)
	assert(Registry.entry(142) == ratman_sibling)
	if active and not ratman:
		check_skeleton_swap()
	if active:
		check_corpses(bodies)
	game.free()
	quit()

func check_route(game: Node, body: int, treatment: String, active: bool) -> bool:
	var clip: String = CLIPS[body]
	var original := Registry.entry(body)
	var base_assets: Dictionary = original.get("classic_gesture_base_assets", {})
	var baseline: String = base_assets.get(treatment, Registry.asset_path(original, treatment))
	var base := (load(baseline) as PackedScene).instantiate()
	var source := base.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var suffix := "" if treatment == "modern" else "-" + treatment
	var path := "res://local-art/creatures/slot11-%d-trial%s.scn" % [body, suffix]
	if active:
		assert(original.status == "validated" and original.assets[treatment] == path)
		assert(original.authored_action_scene_sha256[treatment] == FileAccess.get_sha256(path))
	else:
		var entry := original.duplicate(true)
		entry.assets = {treatment: path}
		entry.classic_action_categories = entry.get("classic_action_categories", {}).merged({"11": clip}, true)
		Registry.entries[body] = entry
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.apply_identity(body, 0x8035)
	var player: AnimationPlayer = actor.animator
	for name in source.get_animation_list():
		var before := source.get_animation(name)
		var after := player.get_animation(name)
		assert(before.length == after.length and before.get_track_count() == after.get_track_count())
		for track in before.get_track_count():
			assert(before.track_get_path(track) == after.track_get_path(track))
			assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track))
	base.free()

	game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0x8035}
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(SERIAL, 4))
	packet.append_array(PackedByteArray([0, 11, 0, 5, 0, 1, 1, 0, 0]))
	game._handle(packet)
	assert(actor.receive_action(game.last_mobile_actions[SERIAL]) and actor.current_clip == clip)
	assert(actor.native_body == body and actor.native_hue == 0x8035)
	var passed := check_pose(actor, clip)
	actor.free()
	Registry.entries[body] = original
	return passed

func check_corpses(bodies: Array) -> void:
	for body: int in bodies:
		for hue in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse != null and corpse.get_meta("static_cadaver"))
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.get_meta("graphic_id") == 0x2006 and corpse.get_meta("death_clip") == "Death")
			assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			corpse.free()

func check_skeleton_swap() -> void:
	var avatar := preload("res://Presentation/HumanAvatar.gd").new()
	avatar.initial_body = 50
	root.add_child(avatar)
	var animated: Node3D = avatar.horse_visual
	assert(animated.animator.has_animation("Reach"))
	avatar.apply_server_appearance({"body": 56, "hue": 0x8035}, [])
	var sibling: Node3D = avatar.horse_visual
	assert(sibling != animated and sibling.native_body == 56)
	assert(not sibling.animator.has_animation("Reach"))
	avatar.apply_server_appearance({"body": 50, "hue": 0x8035}, [])
	var returned: Node3D = avatar.horse_visual
	assert(returned != sibling and returned.native_body == 50)
	assert(returned.animator.has_animation("Reach") and returned.native_hue == 0x8035)
	avatar.free()

func check_pose(actor: Node3D, clip: String) -> bool:
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var hand := rig.find_bone("bip01 r hand")
	var foot := rig.find_bone("bip01 r foot")
	var head := rig.find_bone("bip01 head")
	assert(hand >= 0 and foot >= 0 and head >= 0)
	var root_pose := actor.global_transform
	var hand_start := Vector3.ZERO
	var foot_start := Vector3.ZERO
	var travel := 0.0
	var foot_drift := 0.0
	var minimum := INF
	var face_gap := INF
	var head_start := Vector3.ZERO
	var head_drop := 0.0
	player.play(clip, 0.0)
	player.advance(0.0)
	for sample in 61:
		player.seek(float(sample) / 60.0, true)
		rig.force_update_all_bone_transforms()
		var hand_point := rig.to_global(rig.get_bone_global_pose(hand).origin)
		var foot_point := rig.to_global(rig.get_bone_global_pose(foot).origin)
		var head_point := rig.to_global(rig.get_bone_global_pose(head).origin)
		if sample == 0:
			hand_start = hand_point
			foot_start = foot_point
			head_start = head_point
		head_drop = maxf(head_drop, head_start.y - head_point.y)
		face_gap = minf(face_gap, hand_point.distance_to(head_point))
		travel = maxf(travel, hand_point.distance_to(hand_start))
		foot_drift = maxf(foot_drift, foot_point.distance_to(foot_start))
		minimum = minf(minimum, SkinBounds.deformed_bounds(mesh, rig).position.y)
		assert(actor.global_transform.is_equal_approx(root_pose))
		if sample == 60:
			assert(hand_point.distance_to(hand_start) < 0.0001)
	print(clip, " 61 poses: wrist travel, foot drift, minimum floor, face gap, head drop ",
		[travel, foot_drift, minimum, face_gap, head_drop])
	return (travel > (0.15 if clip == "Hunch" else 0.45) and foot_drift < 0.002 and minimum > -0.03
		and (clip != "Hunch" or head_drop > 0.12) and (clip != "FaceWipe" or face_gap < 0.48))
