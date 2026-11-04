extends "res://../scripts/test-troll-weapon-trial.gd"

const ACTIONS := {
	302: ["occurrence_next/skittering_hopper", "HopperCheck", "bip01 head"],
	776: ["horde_rune/horde_demon", "HordeJawCheck", "bone_jaw"],
}

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func specifications() -> Dictionary:
	return ACTIONS

func batch_name() -> String:
	return "hopper_horde_actions"

func run() -> void:
	if not "--active" in OS.get_cmdline_user_args():
		var path := "res://../work/creatures/%s/candidates.json" % batch_name()
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		Registry.load_index()
		for row: Dictionary in rows:
			Registry.entries[int(row.body)] = row.presentation
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var platform := StaticBody3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.0, 0.1, 10.0)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position.y = -0.05
	platform.add_child(shape)
	root.add_child(platform)
	var specs := specifications()
	for body: int in specs:
		var entry := Registry.entry(body)
		var serial := 0x5000 + body
		game.entities[serial] = {"serial": serial, "body": body, "hue": 0x8035}
		var packet := PackedByteArray([0x6e])
		packet.append_array(Wire.uint_be(serial, 4))
		packet.append_array(PackedByteArray([0, 11, 0, 5, 0, 1, 1, 0, 0]))
		game._handle(packet)
		for treatment: String in ["original", "rounded", "modern"]:
			assert(FileAccess.get_sha256(entry.assets[treatment]) == entry.authored_action_scene_sha256[treatment])
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.apply_identity(body, 0x8035)
			assert(actor.native_hue == 0x8035)
			assert(source_matches(actor.animator, specs[body][0], treatment))
			for tilt: Vector3 in [Vector3.ZERO, Vector3(0.08, 0.0, -0.08), Vector3(-0.09, 0.0, 0.11)]:
				platform.rotation = tilt
				await physics_frame
				await physics_frame
				assert(check_plane(actor, platform, game.last_mobile_actions[serial], body, treatment))
			actor.free()
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse != null and corpse.get_meta("static_cadaver"))
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			corpse.free()
	platform.free()
	game.free()
	print(batch_name(), ": ", specs.size() * 9, " decoded plane runs, unchanged original tracks and ",
		specs.size() * 3, " corpse hues")
	quit()

func source_matches(player: AnimationPlayer, prefix: String, treatment: String) -> bool:
	var path := "res://local-art/creatures/%s-%s.gltf" % [prefix, treatment]
	var model := (load(path) as PackedScene).instantiate()
	var source := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for name in source.get_animation_list():
		var a := source.get_animation(name)
		var b := player.get_animation(name)
		assert(b != null and a.length == b.length and a.get_track_count() == b.get_track_count())
		for track in a.get_track_count():
			assert(a.track_get_path(track) == b.track_get_path(track))
			assert(a.get("tracks/%d/keys" % track) == b.get("tracks/%d/keys" % track))
	model.free()
	return true

func check_plane(actor: Node3D, plane: StaticBody3D, packet: Dictionary, body: int, treatment: String) -> bool:
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var spec: Array = specifications()[body]
	var joint := rig.find_bone(spec[2])
	assert(joint >= 0)
	var native_root := actor.global_transform
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.stop()
	actor.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 60:
		actor._physics_process(1.0 / 60.0)
	update_contact(actor, 0.0)
	var idle_gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.position, plane.basis.y)
	assert(actor.receive_action(packet) and actor.current_clip == spec[1])
	var duration: float = actor.action_remaining
	var gap := INF
	var displacement := 0.0
	var rotation := 0.0
	var first := rig.get_bone_global_pose(joint).origin
	var initial := rig.get_bone_pose_rotation(joint)
	for sample in 73:
		var delta := duration / 72.0
		player.advance(0.0 if sample == 0 else delta)
		actor._physics_process(delta)
		assert(not actor.contact.contacts.is_empty() and actor.global_transform.is_equal_approx(native_root))
		update_contact(actor, delta)
		var pose := rig.get_bone_global_pose(joint)
		displacement = maxf(displacement, rig.to_global(pose.origin).distance_to(rig.to_global(first)))
		rotation = maxf(rotation, initial.angle_to(rig.get_bone_pose_rotation(joint)))
		gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.position, plane.basis.y))
	actor._process(duration + 0.001)
	actor.play_gait(false, 0.0)
	assert(actor.current_clip == "Idle")
	print(body, " ", treatment, " plane ", plane.rotation, " floor, landmark travel and angle ",
		[gap, displacement, rotation], " idle floor ", idle_gap)
	return passes_pose(body, gap, displacement, rotation, idle_gap)

func update_contact(actor: Node3D, delta: float) -> void:
	actor.contact._process_modification_with_delta(delta)
	actor.skeleton.force_update_all_bone_transforms()
	# Manual evaluation bypasses SkeletonModifier3D's completion signal.
	actor.contact.modification_processed.emit()

func passes_pose(body: int, gap: float, displacement: float, rotation: float, _idle_gap: float) -> bool:
	return gap >= -0.025 and (displacement > 0.075 if body == 302 else rotation > 0.30)
