extends "res://../scripts/test-cyclops-titan-ice-actions.gd"

const PACKAGE := "ophidian_terathan_actions"
const INSECTS := [70, 71]
const FORMS := [70, 71, 85]
const MOTIONS := {3:"Death2", 5:"ForelegThrust", 6:"PincerOverhead",
	15:"PincerBrace", 16:"PincerRecoil", 18:"MandibleTwitch"}
const STAFF_MOTIONS := {3:"Death2", 5:"StaffReel", 6:"StaffSweep", 13:"StaffFlare",
	15:"StaffFeint", 16:"StaffGuard", 18:"StaffSettle"}
const StaffClearance := preload("res://../scripts/ophidian-staff-clearance.gd")

func install_packages() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var path := "res://../work/creatures/%s/prepared-client.json" % PACKAGE
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(rows.size() == FORMS.size())
		for row: Dictionary in rows:
			var body := int(row.bodies[0].body)
			assert(body in FORMS and row.status == "prepared" and row.family == PACKAGE)
			Registry.entries[body] = row
	else:
		for body: int in FORMS:
			assert(Registry.entry(body).get("classic_gesture_batch") == PACKAGE)

func run() -> void:
	install_packages()
	var session := Game.new()
	root.add_child(session)
	session.set_process(false)
	for body: int in FORMS:
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue
				and corpse.get_meta("death_clip") == "Death" and corpse.get_meta("static_cadaver"))
			if body == 85:
				assert(corpse.find_child("OphidianMageStaff", true, false) != null)
			corpse.free()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for treatment: String in TREATMENTS:
			for body: int in INSECTS:
				witness_terathan(session, plane, body, treatment)
			sample_mage(session, plane, treatment)
		plane.free()
		await physics_frame
	assert(checked == 2907)
	check_saved_staff()
	print("OPHIDIAN AND TERATHAN: ", checked, " decoded terrain poses and nine static corpse hues")
	quit()

func witness_terathan(session: Node, plane: StaticBody3D, body: int, treatment: String) -> void:
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
	Earlier.check_earlier_keys(player, Registry.entry(body).classic_gesture_base_assets[treatment])
	var normal := plane.global_basis.y.normalized()
	var lowest := INF
	for slot: int in [5, 6, 15, 16, 18, 3]:
		assert(actor.receive_action(decode(session, body, slot)) and actor.current_clip == MOTIONS[slot])
		player.advance(0.15)
		for sample in 17:
			player.seek(player.current_animation_length * sample / 16.0, true)
			var gap := Ground.minimum_plane_gap(actor.skin, rig, rig.global_transform, plane.global_position, normal)
			lowest = minf(lowest, gap)
			assert(actor.global_transform == Transform3D.IDENTITY and gap > -0.009, "%s/%s/%s at %s/%s floor %s" % [body, treatment, slot, plane.rotation, sample, gap])
			checked += 1
		actor.dead = false
	print(body, " ", treatment, " ", plane.rotation, " min gap ", lowest)
	actor.free()

func sample_mage(session: Node, plane: StaticBody3D, treatment: String) -> void:
	var actor := Registry.create(85)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(85, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	Earlier.check_earlier_keys(player, Registry.entry(85).classic_gesture_base_assets[treatment])
	var body := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var solver := StaffClearance.new(body, rig)
	var grip := rig.find_bone("cp_grasp_rhand")
	var staff := rig.find_bone("ophidian mage staff")
	var normal := plane.global_basis.y.normalized()
	var lowest := INF
	for slot: int in [5, 6, 13, 15, 16, 18, 3]:
		assert(actor.receive_action(decode(session, 85, slot)) and actor.current_clip == STAFF_MOTIONS[slot])
		player.advance(0.25)
		for sample in 17:
			player.seek(player.current_animation_length * sample / 16.0, true)
			var body_gap := Ground.minimum_plane_gap(actor.fall.skin, rig, rig.global_transform, plane.global_position, normal)
			var staff_gap := Ground.minimum_plane_gap(actor.staff_skin, rig, rig.global_transform, plane.global_position, normal)
			var gap := minf(body_gap, staff_gap)
			lowest = minf(lowest, gap)
			solver.update_pose()
			assert(not solver.crosses_staff(rig.global_transform * rig.get_bone_global_pose(staff), 0.0, null),
				"Staff intersects body in %s/%s/%s at %s" % [treatment, slot, sample, plane.rotation])
			assert(rig.get_bone_global_pose(grip).origin.distance_to(rig.get_bone_global_pose(staff).origin) < 0.000001)
			assert(actor.global_transform == Transform3D.IDENTITY and gap >= 0.0015,
				"%s group %s frame %s floor %s" % [treatment, slot, sample, gap])
			if slot == 13:
				actor._process(0.0)
				assert(actor.cast_sparks.emitting == (sample >= 4 and sample <= 9))
			checked += 1
	print(treatment, " ", plane.rotation, " floor ", lowest)
	actor.free()

func check_saved_staff() -> void:
	var total := 0
	var peak := 0.0
	for treatment: String in TREATMENTS:
		var model := (load(Registry.asset_path(Registry.entry(85), treatment)) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var body := model.find_child("Body", true, false) as MeshInstance3D
		var solver := StaffClearance.new(body, rig)
		var joint := rig.find_bone("ophidian mage staff")
		for clip: String in STAFF_MOTIONS.values():
			player.stop()
			player.play(clip, 0.0)
			player.advance(0.0)
			var steps := ceili(player.current_animation_length * 480.0)
			var last_axis := Vector3.ZERO
			for frame in steps + 1:
				player.seek(player.current_animation_length * frame / steps, true)
				rig.force_update_all_bone_transforms()
				solver.update_pose()
				var pose := rig.global_transform * rig.get_bone_global_pose(joint)
				assert(not solver.crosses_staff(pose), "%s staff/body crossing at %s frame %d" % [treatment, clip, frame])
				var axis := pose.basis.y.normalized()
				if frame > 0:
					peak = maxf(peak, rad_to_deg(last_axis.angle_to(axis)))
				last_axis = axis
				total += 1
		model.free()
	assert(peak < 1.0, "Staff axis moved %s degrees between 480 Hz samples" % peak)
	print("OPHIDIAN STAFF: ", total, " saved-scene samples, peak step ", peak, " degrees")
