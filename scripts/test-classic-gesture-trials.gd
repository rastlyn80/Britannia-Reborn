extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const SkinBounds := preload("res://Presentation/SkinGeometry.gd")
const CLIPS := {1: "FaceWipe", 3: "ArmsRaise", 50: "Reach"}
const SERIAL := 0x4100

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var historical_skeleton := Registry.entry(56).duplicate(true)
	for body in CLIPS:
		for treatment in ["original", "rounded", "modern"]:
			check_route(game, body, treatment)
	assert(Registry.entry(56) == historical_skeleton)
	game.free()
	quit()

func check_route(game: Node, body: int, treatment: String) -> void:
	var clip: String = CLIPS[body]
	var original := Registry.entry(body)
	var base := (load(Registry.asset_path(original, treatment)) as PackedScene).instantiate()
	var source := base.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var entry := original.duplicate(true)
	var suffix := "" if treatment == "modern" else "-" + treatment
	entry.assets = {treatment: "res://local-art/creatures/slot11-%d-trial%s.scn" % [body, suffix]}
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
	check_pose(actor, clip)
	actor.free()
	Registry.entries[body] = original

func check_pose(actor: Node3D, clip: String) -> void:
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
	player.play(clip, 0.0)
	player.advance(0.0)
	for sample in 61:
		player.seek(float(sample) / 60.0, true)
		rig.force_update_all_bone_transforms()
		var hand_point := rig.to_global(rig.get_bone_global_pose(hand).origin)
		var foot_point := rig.to_global(rig.get_bone_global_pose(foot).origin)
		if sample == 0:
			hand_start = hand_point
			foot_start = foot_point
		face_gap = minf(face_gap, hand_point.distance_to(rig.to_global(rig.get_bone_global_pose(head).origin)))
		travel = maxf(travel, hand_point.distance_to(hand_start))
		foot_drift = maxf(foot_drift, foot_point.distance_to(foot_start))
		minimum = minf(minimum, SkinBounds.deformed_bounds(mesh, rig).position.y)
		assert(actor.global_transform.is_equal_approx(root_pose))
		if sample == 60:
			assert(hand_point.distance_to(hand_start) < 0.0001)
	print(clip, " 61 poses: wrist travel, foot drift, minimum floor, face gap ", [travel, foot_drift, minimum, face_gap])
	assert(travel > 0.45 and foot_drift < 0.002 and minimum > -0.03)
	if clip == "FaceWipe":
		assert(face_gap < 0.48)
