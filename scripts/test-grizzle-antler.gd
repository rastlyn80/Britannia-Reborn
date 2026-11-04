extends "res://../scripts/test-troll-weapon-trial.gd"

const GRIZZLE := 259
const ANTLER := "GrizzleAntlerCheck"
const GRIZZLE_SERIAL := 0x4159

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	if not "--active" in OS.get_cmdline_user_args():
		var path := "res://../work/creatures/grizzle_antler/candidates.json"
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		Registry.load_index()
		for row: Dictionary in rows:
			Registry.entries[int(row.body)] = row.presentation
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[GRIZZLE_SERIAL] = {"serial": GRIZZLE_SERIAL, "body": GRIZZLE, "hue": 0x8035}
	var entry := Registry.entry(GRIZZLE)
	var platform := StaticBody3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.0, 0.1, 10.0)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position.y = -0.05
	platform.add_child(shape)
	root.add_child(platform)
	for treatment: String in ["original", "rounded", "modern"]:
		assert(FileAccess.get_sha256(entry.assets[treatment]) == entry.authored_action_scene_sha256[treatment])
		var actor := Registry.create(GRIZZLE)
		actor.treatment = treatment
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.apply_identity(GRIZZLE, 0x8035)
		assert(actor.native_hue == 0x8035)
		assert(retained_tracks(actor.animator, treatment))
		for tilt: Vector3 in [Vector3.ZERO, Vector3(0.08, 0.0, -0.08), Vector3(-0.09, 0.0, 0.11)]:
			platform.rotation = tilt
			await physics_frame
			await physics_frame
			assert(check_terrain(game, actor, platform, treatment))
		actor.free()
	for hue: int in [0, 53, 0x8035]:
		var posed := Corpses.posed(GRIZZLE, hue)
		assert(posed != null)
		var corpse := Corpses.freeze(posed)
		assert(corpse != null and corpse.get_meta("corpse_body") == GRIZZLE)
		assert(corpse.get_meta("native_hue") == hue and corpse.get_meta("death_clip") == "Death")
		assert(corpse.find_children("*", "AnimationPlayer", true, false).is_empty())
		corpse.free()
		posed.free()
	platform.free()
	game.free()
	print("GRIZZLE ANTLER CHECK: nine decoded actions and finite terrain runs, three corpse hues")
	quit()

func retained_tracks(player: AnimationPlayer, treatment: String) -> bool:
	var source := "res://local-art/creatures/monstrousinterredgrizzle-%s.scn" % treatment
	var model := (load(source) as PackedScene).instantiate()
	var baseline := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip in baseline.get_animation_list():
		var before := baseline.get_animation(clip)
		var after := player.get_animation(clip)
		assert(after != null and before.length == after.length)
		assert(before.get_track_count() == after.get_track_count())
		for track in before.get_track_count():
			assert(before.track_get_path(track) == after.track_get_path(track))
			assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track))
	model.free()
	return true

func check_terrain(game: Node, actor: Node3D, platform: StaticBody3D, treatment: String) -> bool:
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var native_root := actor.global_transform
	var head := rig.find_bone("bip01 head")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.stop()
	actor.dead = false
	actor.play("Idle", 0.0)
	for frame in 20:
		player.advance(1.0 / 60.0)
		actor._physics_process(1.0 / 60.0)
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(GRIZZLE_SERIAL, 4))
	packet.append_array(PackedByteArray([0, 11, 0, 5, 0, 1, 1, 0, 0]))
	game._handle(packet)
	assert(actor.receive_action(game.last_mobile_actions[GRIZZLE_SERIAL]))
	assert(actor.current_clip == ANTLER)
	var previous := rig.to_global(rig.get_bone_global_pose(head).origin)
	var heights: Array[float] = []
	var step := 0.0
	var minimum := INF
	var count := 0
	var seconds: float = actor.action_remaining
	for frame in 73:
		var delta := seconds / 72.0
		player.advance(0.0 if frame == 0 else delta)
		actor._physics_process(delta)
		if not actor.contact.contacts.is_empty():
			count += 1
			actor.contact._process_modification_with_delta(delta)
			actor.support_control_plane()
		rig.force_update_all_bone_transforms()
		var point := rig.to_global(rig.get_bone_global_pose(head).origin)
		step = maxf(step, point.distance_to(previous))
		previous = point
		heights.append(point.y)
		minimum = minf(minimum, Ground.minimum_plane_gap(skin, rig, rig.global_transform, platform.position, platform.basis.y))
		assert(actor.global_transform.is_equal_approx(native_root))
	var first_lift: float = heights.slice(10, 28).max() - heights[0]
	var second_lift: float = heights.slice(47, 65).max() - heights.slice(29, 46).min()
	print(treatment, " antler floor, first and second head lifts, maximum head step, ray contacts ",
		[minimum, first_lift, second_lift, step, count], " at ", platform.rotation)
	return minimum >= -0.008 and first_lift > 0.35 and second_lift > 0.50 and step < 0.28 and count == 73
