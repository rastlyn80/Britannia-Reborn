extends "res://../scripts/test-mage-lord-tentacle-actions.gd"

const PACKAGE := "avenger_rotting_actions"
const CLASSIC := {
	152: {2:"Death", 3:"Death", 4:"Attack", 5:"Attack2", 6:"Attack2", 10:"Hit", 11:"Fidget",
		15:"AvengerPincerRecoil", 16:"AvengerPincerRecoil", 17:"Fidget", 18:"AvengerThreat"},
	155: {2:"Death2", 3:"Death", 4:"BackhandReach", 5:"Attack", 6:"OverheadClaw", 10:"Hit",
		11:"ArmsRaise", 12:"Cast", 14:"Cast", 15:"DoubleOver", 16:"StaggerBack", 17:"Fidget", 18:"LookUp"},
}

static func install_routes() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var path := "res://../work/creatures/%s/prepared-client.json" % PACKAGE
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(rows.size() == CLASSIC.size())
		for row: Dictionary in rows:
			var body := int(row.bodies[0].body)
			assert(body in CLASSIC and row.status == "prepared" and row.family == PACKAGE)
			Registry.entries[body] = row
	else:
		for body: int in CLASSIC:
			assert(Registry.entry(body).get("classic_gesture_batch") == PACKAGE)
	assert(Registry.entry(3).kind == "walking_dead_zombie" and Registry.entry(70).kind == "terathan_terathan_warrior")

func run() -> void:
	install_routes()
	var session := Game.new()
	root.add_child(session)
	session.set_process(false)
	for body: int in CLASSIC:
		for hue: int in [0, 0x480 if body == 155 else 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue
				and corpse.get_meta("death_clip") == "Death" and corpse.get_meta("static_cadaver"))
			corpse.free()
		for tilt: Vector3 in SLOPES:
			var plane := await support(tilt)
			for treatment: String in TREATMENTS:
				sample_actions(session, body, treatment, plane)
			plane.free()
			await physics_frame
	assert(checked == 3672)
	print("TERATHAN AVENGER AND ROTTING CORPSE: ", checked, " decoded terrain poses and six static corpse hues")
	quit()

func sample_actions(session: Node, body: int, treatment: String, plane: StaticBody3D) -> void:
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
	assert(rig.get_bone_count() == (57 if body == 152 else 34))
	if plane.rotation == Vector3.ZERO:
		Earlier.check_earlier_keys(player, Registry.entry(body).classic_gesture_base_assets[treatment])
		if body == 152:
			check_distinct_attacks(player)
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var normal := plane.global_basis.y.normalized()
	var neutral: Transform3D = actor.model.transform
	for slot: int in CLASSIC[body]:
		actor.dead = false
		if body == 155:
			actor.fall.shift = Vector3.ZERO
			actor.clearance_lift = Vector3.ZERO
			actor.model.transform = neutral
		player.stop()
		assert(actor.receive_action(decode(session, body, slot)))
		assert(actor.current_clip == CLASSIC[body][slot])
		player.advance(0.15)
		var lowest := INF
		for step in 17:
			player.seek(player.current_animation_length * step / 16.0, true)
			if body == 155 and not actor.dead:
				for settle in 8:
					actor._physics_process(1.0 / 30.0)
					actor.contact._process_modification_with_delta(1.0 / 30.0)
				actor.support_control_plane()
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
			var minimum := 0.0015 if body == 152 else -0.004
			assert(gap >= minimum and actor.global_transform == Transform3D.IDENTITY and actor.native_hue == 0x8035,
				"%d/%s group %d, tilt %s, phase %d, gap %.6f" % [body, treatment, slot, plane.rotation, step, gap])
			lowest = minf(lowest, gap)
			checked += 1
		print(body, " ", treatment, " group ", slot, " slope ", plane.rotation, " minimum ", lowest)
	actor.free()

func check_distinct_attacks(player: AnimationPlayer) -> void:
	var attack := player.get_animation("Attack")
	var attack2 := player.get_animation("Attack2")
	for track in attack.get_track_count():
		if attack.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var other := attack2.find_track(attack.track_get_path(track), Animation.TYPE_ROTATION_3D)
		if other >= 0 and attack.rotation_track_interpolate(track, attack.length / 2.0).angle_to(
			attack2.rotation_track_interpolate(other, attack2.length / 2.0)) > 0.1:
			return
	assert(false, "Expected two distinct recovered Avenger attacks")
