extends "res://../scripts/test-mage-lord-tentacle-actions.gd"

const PACKAGE := "solen_worker_actions"
const WORKERS := [781, 805]
const ROUTES := {11: "Fidget", 15: "WorkerBrace", 16: "WorkerBrace", 17: "Fidget", 18: "Fidget2"}

static func install_worker_routes() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var path := "res://../work/creatures/%s/prepared-client.json" % PACKAGE
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(rows.size() == WORKERS.size())
		for row: Dictionary in rows:
			var body := int(row.bodies[0].body)
			assert(body in WORKERS and row.status == "prepared" and row.family == PACKAGE)
			Registry.entries[body] = row
	else:
		for body: int in WORKERS:
			assert(Registry.entry(body).get("classic_gesture_batch") == PACKAGE)

func run() -> void:
	install_worker_routes()
	var session := Game.new()
	root.add_child(session)
	session.set_process(false)
	for body: int in WORKERS:
		var row := Registry.entry(body)
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue
				and corpse.get_meta("death_clip") == "Death" and corpse.get_meta("static_cadaver"))
			corpse.free()
		for tilt: Vector3 in SLOPES:
			var plane := await support(tilt)
			for treatment: String in TREATMENTS:
				sample_worker(session, body, row.classic_gesture_base_assets[treatment], treatment, plane)
			plane.free()
			await physics_frame
	assert(checked == 1530)
	print("SOLEN WORKER BRACE: ", checked, " decoded terrain poses and six static corpse hues")
	quit()

func sample_worker(session: Node, body: int, base: String, treatment: String, plane: StaticBody3D) -> void:
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	assert(rig.get_bone_count() == 42 and actor.contact.feet.size() == 6)
	if plane.rotation == Vector3.ZERO:
		Earlier.check_earlier_keys(player, base)
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var normal := plane.global_basis.y.normalized()
	var min_brace := INF
	var max_brace := -INF
	var head := rig.find_bone("bip01 head")
	var antenna := rig.find_bone("antenna l")
	for slot: int in ROUTES:
		player.stop()
		assert(actor.receive_action(decode(session, body, slot)))
		assert(actor.current_clip == ROUTES[slot])
		player.advance(0.16)
		player.seek(0.0, true)
		var first_head := rig.get_bone_global_pose(head).origin
		var first_antenna := rig.get_bone_pose_rotation(antenna)
		var max_head_motion := 0.0
		var max_antenna_motion := 0.0
		for step in 17:
			player.seek(player.current_animation_length * step / 16.0, true)
			for frame in 12:
				actor._process(1.0 / 30.0)
				actor._physics_process(1.0 / 30.0)
				actor.contact._process_modification_with_delta(1.0 / 30.0)
			rig.force_update_all_bone_transforms()
			assert(actor.contact.contacts.size() == 6)
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
			assert(gap >= -0.009 and actor.global_transform == Transform3D.IDENTITY and actor.native_hue == 0x8035,
				"%s/%s/%d/%.3f phase %d minimum skin gap %.5f" % [body, treatment, slot, normal.x, step, gap])
			if slot in [15, 16]:
				min_brace = minf(min_brace, gap)
				max_brace = maxf(max_brace, gap)
				max_head_motion = maxf(max_head_motion, rig.get_bone_global_pose(head).origin.distance_to(first_head))
				max_antenna_motion = maxf(max_antenna_motion, rig.get_bone_pose_rotation(antenna).angle_to(first_antenna))
			checked += 1
		if slot in [15, 16]:
			assert(max_head_motion > 0.04 and max_antenna_motion > 0.30,
				"Expected visible head and antenna brace movement: %s / %s" % [max_head_motion, max_antenna_motion])
	print(body, " ", treatment, " ", plane.rotation, " brace skin [", min_brace, ", ", max_brace, "] m")
	actor.free()
