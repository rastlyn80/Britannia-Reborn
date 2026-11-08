extends "res://../scripts/test-mage-lord-tentacle-actions.gd"

const BATCH := "cyclops_titan_ice_actions"
const NEXT_BODIES := [75, 76, 161]
const ROUTES := {
	75: {3:"Death2", 4:"MalletSideSweep", 5:"Attack", 6:"MalletLunge", 11:"MalletDip",
		15:"MalletHighBrace", 16:"MalletRearBrace", 18:"MalletCheck"},
	76: {6:"Attack2", 11:"Fidget", 15:"TitanBrace", 16:"TitanBrace", 17:"Fidget", 18:"TitanOath"},
	161: {15:"IceArmDraw", 16:"IceForearmGuard", 18:"IceWeightShift"},
}
const MALLET_TERRAIN_GROUPS := [4, 5, 6, 15, 16, 18, 3]
const Clearance := preload("res://../scripts/bone-knight-cyclops-clearance.gd")

func load_batch() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var path := "res://../work/creatures/%s/prepared-client.json" % BATCH
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(rows.size() == NEXT_BODIES.size())
		for row: Dictionary in rows:
			var body := int(row.bodies[0].body)
			assert(body in NEXT_BODIES and row.status == "prepared" and row.family == BATCH)
			Registry.entries[body] = row
	else:
		for body: int in NEXT_BODIES:
			assert(Registry.entry(body).get("classic_gesture_batch") == BATCH)

func run() -> void:
	load_batch()
	var session := Game.new()
	root.add_child(session)
	session.set_process(false)
	for body: int in NEXT_BODIES:
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue
				and corpse.get_meta("death_clip") == "Death" and corpse.get_meta("static_cadaver"))
			if body == 75:
				assert(corpse.find_child("CyclopsMallet", true, false) != null)
			corpse.free()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for treatment: String in TREATMENTS:
			sample_prop(session, treatment, plane)
			for body: int in [76, 161]:
				sample_body(session, body, treatment, plane)
		plane.free()
		await physics_frame
	assert(checked == 2448)
	print("CYCLOPS, TITAN AND ICE ELEMENTAL: ", checked, " decoded terrain poses and nine corpse hue checks")
	quit()

func sample_prop(session: Node, treatment: String, plane: StaticBody3D) -> void:
	var actor := Registry.create(75)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(75, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var body := actor.model.find_child("Body", true, false) as MeshInstance3D
	var solver := Clearance.new(body, rig)
	var grip := rig.find_bone("cp_grasp_rhand")
	var mallet := rig.find_bone("cyclopsmallet")
	var normal := plane.global_basis.y.normalized()
	for group: int in MALLET_TERRAIN_GROUPS:
		assert(actor.receive_action(decode(session, 75, group)))
		assert(actor.current_clip == ROUTES[75][group])
		player.advance(0.17)
		var lowest := INF
		for frame in 17:
			player.seek(player.current_animation_length * (frame + 0.37) / 17.0, true)
			var body_gap := Ground.minimum_plane_gap(actor.body_skin, rig, rig.global_transform, plane.global_position, normal)
			var mallet_gap := Ground.minimum_plane_gap(actor.mallet_skin, rig, rig.global_transform, plane.global_position, normal)
			var gap := minf(body_gap, mallet_gap)
			lowest = minf(lowest, gap)
			assert(actor.global_transform == Transform3D.IDENTITY and gap >= 0.0015)
			assert(rig.get_bone_global_pose(grip).origin.distance_to(rig.get_bone_global_pose(mallet).origin) < 0.000001)
			solver.update_pose()
			assert(not solver.crosses_prop(rig.global_transform * rig.get_bone_global_pose(mallet), "CyclopsMallet"))
			checked += 1
		print(treatment, " group ", group, " ", plane.rotation, " minimum body/mallet gap ", lowest)
	actor.free()

func sample_body(session: Node, body: int, treatment: String, plane: StaticBody3D) -> void:
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
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var normal := plane.global_basis.y.normalized()
	var highest_penetration := 0.0
	for group: int in ROUTES[body]:
		assert(actor.receive_action(decode(session, body, group)))
		assert(actor.current_clip == ROUTES[body][group])
		player.advance(0.16)
		for frame in 17:
			if body == 76:
				actor.release_gesture_lift()
			player.seek(player.current_animation_length * frame / 16.0, true)
			actor.contact.sample(plane.get_world_3d().direct_space_state, actor.global_position)
			actor.contact._process_modification_with_delta(0.0)
			if body == 76:
				actor.clear_gesture_ground()
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
			highest_penetration = maxf(highest_penetration, -gap)
			assert(actor.global_transform == Transform3D.IDENTITY and is_finite(gap))
			assert(gap >= -0.012, "Body %d %s clip %d, frame %d clearance %s" % [body, treatment, group, frame, gap])
			checked += 1
	print(body, " ", treatment, " slope ", plane.rotation, " max penetration ", highest_penetration)
	actor.free()
