extends SceneTree

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const BODY := 753
const SERIAL := 0x4100

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var row := Registry.entry(BODY).duplicate(true)
	assert(row.kind == "gargoyles_gargoyle_slave")
	var originals: Dictionary = row.assets.duplicate(true)
	for treatment in ["original", "rounded", "modern"]:
		var suffix: String = "" if treatment == "modern" else "-" + treatment
		row.assets[treatment] = "res://local-art/creatures/gargoyle-753-pillage-trial%s.scn" % suffix
	row.classic_action_categories["11"] = "Pillage"
	Registry.entries[BODY] = row

	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[SERIAL] = {"serial": SERIAL, "body": BODY, "hue": 0x8035}
	for treatment in ["original", "rounded", "modern"]:
		var actor := Registry.create(BODY)
		actor.treatment = treatment
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.apply_identity(BODY, 0x8035)
		var player: AnimationPlayer = actor.animator
		var baseline := (load(originals[treatment]) as PackedScene).instantiate()
		var baseline_player := baseline.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		assert(player.has_animation("Pillage") and not baseline_player.has_animation("Pillage"))
		for name in baseline_player.get_animation_list():
			var source := baseline_player.get_animation(name)
			var actual := player.get_animation(name)
			assert(actual.length == source.length and actual.get_track_count() == source.get_track_count())
			for track in source.get_track_count():
				assert(actual.track_get_path(track) == source.track_get_path(track))
				assert(actual.get("tracks/%d/keys" % track) == source.get("tracks/%d/keys" % track))
		baseline.free()
		for action in [[17, "Fidget"], [12, "Cast"], [14, "Cast"], [11, "Pillage"]]:
			var packet := PackedByteArray([0x6e])
			packet.append_array(Wire.uint_be(SERIAL, 4))
			packet.append_array(PackedByteArray([0, action[0], 0, 5, 0, 1, 1, 0, 0]))
			game._handle(packet)
			assert(actor.receive_action(game.last_mobile_actions[SERIAL]))
			assert(actor.current_clip == action[1])
		assert(actor.native_hue == 0x8035)
		check_pose(actor, treatment)
		actor.free()
	game.free()
	quit()

func check_pose(actor: Node3D, treatment: String) -> void:
	var rig: Skeleton3D = actor.skeleton
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var player: AnimationPlayer = actor.animator
	var data := Ground.skin_points(mesh, rig)
	var bones: Array[int] = []
	for name in ["bip01 r foot", "bip01 l foot", "bip01 pelvis", "bip01 r hand", "bip01 l hand"]:
		var bone := rig.find_bone(name)
		assert(bone >= 0)
		bones.append(bone)
	var start: Array[Vector3] = []
	var foot_drift := 0.0
	var minimum := INF
	var crouch := 0.0
	var reach := 0.0
	var fixed_root := actor.global_transform
	player.play("Pillage", 0.0)
	player.advance(0.0)
	for sample in 97:
		player.seek(player.get_animation("Pillage").length * float(sample) / 96.0, true)
		rig.force_update_all_bone_transforms()
		var points: Array[Vector3] = []
		for bone in bones:
			points.append(rig.to_global(rig.get_bone_global_pose(bone).origin))
		if sample == 0:
			start = points.duplicate()
		foot_drift = maxf(foot_drift, maxf(points[0].distance_to(start[0]), points[1].distance_to(start[1])))
		crouch = maxf(crouch, start[2].y - points[2].y)
		reach = maxf(reach, maxf(points[3].z - start[3].z, points[4].z - start[4].z))
		minimum = minf(minimum, Ground.minimum_plane_gap(data, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		assert(actor.global_transform.is_equal_approx(fixed_root))
		if sample == 96:
			for i in bones.size():
				assert(points[i].distance_to(start[i]) < 0.0001)
	print("Gargoyle 753 ", treatment, " 97 poses: ankle drift, crouch, reach, floor ", [foot_drift, crouch, reach, minimum])
	assert(foot_drift < 0.002 and crouch > 0.45 and reach > 0.40 and minimum > -0.005)
