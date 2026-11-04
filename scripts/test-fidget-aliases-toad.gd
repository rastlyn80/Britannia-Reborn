extends "res://../scripts/test-troll-weapon-trial.gd"

const CLASSIC_GROUPS := {67: {11: "Fidget", 17: "Fidget"}, 80: {11: "ToadGulp"}, 149: {11: "Fidget", 17: "Fidget"}}
const TREATMENTS := ["original", "rounded", "modern"]

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	if not "--active" in OS.get_cmdline_user_args():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(
			"res://../work/creatures/fidget_aliases_toad/candidates.json"))
		Registry.load_index()
		for row: Dictionary in rows:
			Registry.entries[int(row.body)] = row.presentation
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	for body: int in CLASSIC_GROUPS:
		var entry := Registry.entry(body)
		var serial := 0x4100 + body
		game.entities[serial] = {"serial": serial, "body": body, "hue": 0x8035}
		for treatment: String in TREATMENTS:
			assert(FileAccess.get_sha256(entry.assets[treatment]) == entry.authored_action_scene_sha256[treatment])
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.apply_identity(body, 0x8035)
			assert(source_tracks_match(actor.animator, entry.kind, treatment))
			for group: int in CLASSIC_GROUPS[body]:
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(serial, 4))
				packet.append_array(PackedByteArray([0, group, 0, 5, 0, 1, 1, 0, 0]))
				game._handle(packet)
				assert(actor.receive_action(game.last_mobile_actions[serial]))
				assert(actor.current_clip == CLASSIC_GROUPS[body][group])
			if body == 80:
				assert(check_gulp(actor))
			actor.free()
		for hue in [0, 53, 0x8035]:
			var posed := Corpses.posed(body, hue)
			assert(posed != null)
			var corpse := Corpses.freeze(posed)
			assert(corpse != null and corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			corpse.free()
			posed.queue_free()
	game.free()
	print("FIDGET ALIASES AND TOAD: 15 decoded routes, unchanged original tracks, three gulp treatments and nine corpse hues")
	quit()

func source_tracks_match(player: AnimationPlayer, kind: String, treatment: String) -> bool:
	var path := "res://local-art/creatures/%s-%s.gltf" % [kind, treatment]
	var model := (load(path) as PackedScene).instantiate()
	var source := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip in source.get_animation_list():
		var before := source.get_animation(clip)
		var after := player.get_animation(clip)
		assert(after != null and after.length == before.length)
		assert(before.get_track_count() == after.get_track_count())
		for track in before.get_track_count():
			assert(before.track_get_path(track) == after.track_get_path(track))
			assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track))
	model.free()
	return true

func joint_point(rig: Skeleton3D, joint: int) -> Vector3:
	return rig.to_global(rig.get_bone_global_pose(joint).origin)

func check_gulp(actor: Node3D) -> bool:
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var head := rig.find_bone("bip01 head")
	var tongue := rig.find_bone("bip01 ponytail11")
	assert(head >= 0 and tongue >= 0)
	player.stop()
	player.play("ToadGulp", 0.0)
	player.advance(0.0)
	rig.force_update_all_bone_transforms()
	var start_head := joint_point(rig, head)
	var start_tongue := joint_point(rig, tongue)
	var head_travel := 0.0
	var tongue_travel := 0.0
	var floor := INF
	for sample in 91:
		player.seek(player.current_animation_length * float(sample) / 90.0, true)
		rig.force_update_all_bone_transforms()
		head_travel = maxf(head_travel, joint_point(rig, head).distance_to(start_head))
		tongue_travel = maxf(tongue_travel, joint_point(rig, tongue).distance_to(start_tongue))
		floor = minf(floor, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
	print(actor.treatment, " toad head and tongue travel, minimum floor gap ", [head_travel, tongue_travel, floor])
	return head_travel > 0.005 and tongue_travel > 0.003 and floor > -0.012 \
		and joint_point(rig, head).distance_to(start_head) < 0.0005
