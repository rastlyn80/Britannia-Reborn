extends "res://../scripts/test-gargoyle-kitsune-larva-actions.gd"

const BATCH := "post_solen_actions"
const POST_SOLEN_BODIES := [248, 303, 251, 787, 300, 263, 253, 305]
const Bake := preload("res://../scripts/bake-post-solen-actions.gd")
const NewPacket := preload("res://../scripts/test-efreet-actions.gd")
var classic := 0
var newer := 0
var corpses := 0
var minimum := INF
var gaman_checks := 0

func run() -> void:
	Registry.load_index()
	var index := "res://local-art/creatures/accepted-index.json"
	var digest := FileAccess.get_sha256(index)
	var active := "--active" in OS.get_cmdline_user_args()
	if not active:
		var file := "res://../work/creatures/%s/prepared-client.json" % BATCH
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(file))
		assert(rows.size() == POST_SOLEN_BODIES.size())
		for row: Dictionary in rows:
			Registry.entries[int(row.bodies[0].body)] = row
	var session := Game.new()
	root.add_child(session)
	session.set_process(false)
	var expected_newer := 0
	var expected_poses := 0
	for body: int in POST_SOLEN_BODIES:
		var row := Registry.entry(body)
		assert(row.get("classic_gesture_batch" if active else "family") == BATCH)
		session.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		for treatment: String in row.assets:
			check_routes(session, body, treatment)
			expected_newer += row.new_action_categories.size()
			expected_poses += terrain_clips(body, row).size() * SLOPES.size() * 31
		for hue: int in [0, 53, 0x8035]:
			var cadaver := Corpses.build(body, hue)
			assert(cadaver.get_meta("corpse_body") == body and cadaver.get_meta("native_hue") == hue)
			assert(cadaver.get_meta("static_cadaver") and cadaver.get_meta("death_clip") == "Death")
			assert(cadaver.find_children("*", "AnimationPlayer", true, false).is_empty())
			cadaver.free()
			corpses += 1
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for body: int in POST_SOLEN_BODIES:
			for treatment: String in Registry.entry(body).assets:
				sample_archive_ground(plane, body, treatment)
		plane.free()
		await physics_frame
	assert(FileAccess.get_sha256(index) == digest and classic == 312 and newer == expected_newer and corpses == 24)
	assert(checked == expected_poses and minimum >= 0.0004 and gaman_checks == 9)
	print("POST-SOLEN ACTIONS: ", checked, " terrain poses, ", classic, " Classic and ", newer,
		" newer decoded selections, ", corpses, " static corpse hues. Lowest gap ", minimum, " m")
	quit()

func ready_actor(body: int, treatment: String) -> Node3D:
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor

func check_routes(session: Node, body: int, treatment: String) -> void:
	var actor := ready_actor(body, treatment)
	var player: AnimationPlayer = actor.animator
	var base: String = actor.entry.classic_gesture_base_assets[treatment]
	if body == 248:
		# The existing renderer adds a placement track to the recovered LieDown.
		# Compare the stored clips before it applies that runtime adjustment.
		var saved := (load(actor.entry.assets[treatment]) as PackedScene).instantiate()
		var saved_player := saved.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		Earlier.check_earlier_keys(saved_player, base)
		saved.free()
	else:
		Earlier.check_earlier_keys(player, base)
	for slot: String in actor.entry.classic_motion_references:
		actor.dead = false
		player.stop()
		var packet := decode(session, body, int(slot))
		assert(packet.body == body and actor.receive_action(packet))
		assert(actor.current_clip == actor.entry.classic_action_categories[slot] and actor.get_meta("native_action") == packet)
		classic += 1
	for kind: String in actor.entry.new_action_categories:
		actor.dead = false
		player.stop()
		var packet := NewPacket.decode_new(session, body, int(kind), 0, 0)
		assert(packet.body == body and actor.receive_action(packet))
		assert(actor.current_clip == actor.entry.new_action_categories[kind] and actor.get_meta("native_action") == packet)
		newer += 1
	actor.free()

func terrain_clips(body: int, row: Dictionary) -> Array:
	if body == 248:
		return ["Alert", "GamanLowGuard"]
	return Bake.NEXT[body].values() if body == 787 else row.archive_grounded_gestures

func sample_archive_ground(plane: StaticBody3D, body: int, treatment: String) -> void:
	var actor := ready_actor(body, treatment)
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var normal := plane.global_basis.y.normalized()
	var anchor := actor.global_transform
	var head := rig.find_bone("bip01 head") if body == 248 else -1
	var raised := INF
	var lowered := -INF
	var guard_rotation := 0.0
	for clip: String in terrain_clips(body, actor.entry):
		player.stop()
		actor.current_clip = clip
		player.play(clip, 0.0)
		player.advance(0.0)
		var start_rotation := Quaternion.IDENTITY
		for frame in 31:
			player.seek(player.current_animation_length * frame / 30.0, true)
			actor._physics_process(1.0 / 60.0)
			actor.contact._process_modification_with_delta(1.0 / 60.0)
			rig.force_update_all_bone_transforms()
			actor.contact.modification_processed.emit()
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
			assert(is_finite(gap) and gap >= (0.0004 if body == 248 else 0.0014) and actor.global_transform == anchor,
				str([body, treatment, clip, frame, gap]))
			if head >= 0:
				var pose := rig.get_bone_global_pose(head)
				var height := rig.to_global(pose.origin).y
				if clip == "Alert":
					raised = minf(raised, height)
				else:
					lowered = maxf(lowered, height)
					var rotation := pose.basis.get_rotation_quaternion()
					if frame == 0:
						start_rotation = rotation
					guard_rotation = maxf(guard_rotation, start_rotation.angle_to(rotation))
			minimum = minf(minimum, gap)
			checked += 1
	if head >= 0:
		assert(raised - lowered > 0.12 and guard_rotation > 0.2)
		gaman_checks += 1
	actor.free()
