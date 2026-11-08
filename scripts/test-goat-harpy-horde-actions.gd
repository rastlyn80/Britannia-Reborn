extends "res://../scripts/test-mage-lord-tentacle-actions.gd"

const PACKAGE := "goat_harpy_horde_actions"
const CLASSIC := {
	88: {4:"LookSide", 5:"Attack", 6:"Attack2", 8:"Death", 9:"Fidget", 10:"Fidget2", 12:"Death2"},
	87: {3:"Death2", 6:"MatriarchTailStrike", 15:"MatriarchOverheadBrace", 16:"MatriarchRecoil", 18:"MatriarchTailLift"},
	79: {3:"Death2", 13:"LordCastingReach", 15:"LordFreeHandGuard", 16:"LordStaffRaise", 18:"LordShoulderTurn"},
	149: {3:"Death", 15:"SuccubusWingRecoil", 16:"SuccubusWingRecoil", 18:"SuccubusWingLift"},
	73: {2:"Death", 3:"Death2", 5:"RaisedWingKick", 6:"WingRush", 11:"Wingbeat", 15:"WingTuckRecoil",
		16:"WideWingRecoil", 18:"FeatherFlick", 19:"Fly", 20:"Land", 21:"AirDeath"},
	776: {3:"Death2", 15:"HordeBrace", 16:"HordeBrace", 18:"HordeGlance"},
}

func install_packages() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var path := "res://../work/creatures/%s/prepared-client.json" % PACKAGE
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(rows.size() == CLASSIC.size())
		for row: Dictionary in rows:
			var body := int(row.bodies[0].body)
			assert(body in CLASSIC and row.status == "prepared" and row.family == PACKAGE)
			if body == 79:
				row.kind += "_actions_79"
			Registry.entries[body] = row
	else:
		for body: int in CLASSIC:
			assert(Registry.entry(body).get("classic_gesture_batch") == PACKAGE)
	assert(Registry.entry(78).kind == "liche_liche_lord_retro"
		and Registry.entry(82).kind == "liche_liche_lord_retro")
	assert(Registry.entry(30).kind == "harpies_harpy")

func run() -> void:
	install_packages()
	var session := Game.new()
	root.add_child(session)
	session.set_process(false)
	for body: int in CLASSIC:
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue
				and corpse.get_meta("death_clip") == "Death" and corpse.get_meta("static_cadaver"))
			corpse.free()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for body: int in CLASSIC:
			for treatment: String in TREATMENTS:
				sample_actions(session, body, treatment, plane)
		plane.free()
		await physics_frame
	assert(checked == 5508)
	print("GOAT, MATRIARCH, LICH LORD, SUCCUBUS, STONE HARPY AND HORDE: ", checked,
		" decoded terrain poses and 18 static corpse hues")
	quit()

func sample_actions(session: Node, body: int, treatment: String, plane: StaticBody3D) -> void:
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if plane.rotation == Vector3.ZERO:
		Earlier.check_earlier_keys(player, Registry.entry(body).classic_gesture_base_assets[treatment])
	var rig: Skeleton3D = actor.skeleton
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	if body == 79 and treatment == "modern":
		var material := mesh.get_surface_override_material(0) as ShaderMaterial
		assert(actor.staff != null and material.get_shader_parameter("use_accent"))
	var normal := plane.global_basis.y.normalized()
	var lowest := INF
	for slot: int in CLASSIC[body]:
		actor.dead = false
		player.stop()
		assert(actor.receive_action(decode(session, body, slot)) and actor.current_clip == CLASSIC[body][slot])
		if body == 73 and slot == 11:
			assert(not actor.contact.enabled)
		player.advance(0.15)
		for frame in 17:
			player.seek(player.current_animation_length * frame / 16.0, true)
			if body in [73, 79] and not actor.dead:
				for step in 9:
					actor._physics_process(1.0 / 30.0)
					actor.contact._process_modification_with_delta(1.0 / 30.0)
					if body == 73:
						actor.clear_gesture_ground()
					else:
						actor.settle_lord_gesture()
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
			if body == 79 and treatment == "modern":
				var staff_floor: float = actor.staff_gap(actor.staff.global_transform, normal)
				staff_floor += (actor.model.global_position - plane.global_position).dot(normal)
				gap = minf(gap, staff_floor)
			var threshold := -0.012 if body in [73, 79] and not actor.dead else 0.0015
			assert(gap >= threshold and actor.global_transform == Transform3D.IDENTITY and actor.native_hue == 0x8035,
				"%d %s slot %d, tilt %s, frame %d, floor %.6f" % [body, treatment, slot, plane.rotation, frame, gap])
			lowest = minf(lowest, gap)
			checked += 1
	print(body, " ", treatment, " ", plane.rotation, " minimum floor gap ", lowest)
	actor.free()
