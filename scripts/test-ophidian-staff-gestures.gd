extends "res://../scripts/test-troll-weapon-trial.gd"

const MAGE := 85
const QUEEN := 87
const PROP := "OphidianMageStaff"
const StaffClearance := preload("res://../scripts/ophidian-staff-clearance.gd")
const MOTIONS := ["Idle", "Walk", "Run", "Attack", "Hit", "Fidget", "StaffDip", "StaffCast", "Cast2", "Death"]

func _initialize() -> void:
	create_timer(60.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	if not "--active" in OS.get_cmdline_user_args():
		var path := "res://../work/creatures/ophidian_staff/candidates.json"
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		Registry.load_index()
		for candidate: Dictionary in rows:
			Registry.entries[int(candidate.body)] = candidate.presentation
	else:
		var successors := {MAGE: "ophidian_terathan_actions", QUEEN: "goat_harpy_horde_actions"}
		for body: int in successors:
			var batch: String = successors[body]
			if Registry.entry(body).get("classic_gesture_batch") != batch:
				continue
			var path := "res://../work/creatures/%s/accepted-native/base-rows.json" % batch
			var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
			for row: Dictionary in rows:
				if int(row.bodies[0].body) == body:
					Registry.entries[body] = row
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	for body: int in [MAGE, QUEEN]:
		var entry := Registry.entry(body)
		var serial := 0x4100 + body
		game.entities[serial] = {"serial": serial, "body": body, "hue": 0x8035}
		for treatment: String in ["original", "rounded", "modern"]:
			assert(FileAccess.get_sha256(entry.assets[treatment]) == entry.authored_action_scene_sha256[treatment])
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.apply_identity(body, 0x8035)
			assert(preserved(actor, entry.kind, treatment, int(body == MAGE)))
			for slot: String in entry.classic_motion_references:
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(serial, 4))
				packet.append_array(PackedByteArray([0, int(slot), 0, 5, 0, 1, 1, 0, 0]))
				game._handle(packet)
				assert(actor.receive_action(game.last_mobile_actions[serial]))
				assert(actor.current_clip == entry.classic_action_categories[slot])
				if slot in ["12", "14"]:
					assert(check_sparks(actor, slot == "14"))
			if body == MAGE:
				assert(check_staff(actor, treatment))
			else:
				assert(actor.find_child(PROP, true, false) == null)
				assert(check_queen(actor))
			actor.free()
	for hue in [0, 53, 0x8035]:
		check_corpse(MAGE, hue, PROP)
		var posed := Corpses.posed(QUEEN, hue)
		assert(posed != null)
		var corpse := Corpses.freeze(posed)
		assert(corpse != null and corpse.get_meta("corpse_body") == QUEEN and corpse.get_meta("native_hue") == hue)
		assert(corpse.find_child(PROP, true, false) == null)
		corpse.free()
		posed.queue_free()
	await check_handoff(MAGE, PROP, Vector3.RIGHT, 0.0)
	for axis in [Vector3.RIGHT, Vector3.FORWARD]:
		for slope in [-0.14, 0.14]:
			await check_handoff(MAGE, PROP, axis, slope)
	await check_handoff(MAGE, PROP, Vector3.RIGHT, 0.0, 0.35)
	await check_handoff(MAGE, PROP, Vector3.RIGHT, 0.0, -0.35)
	game.free()
	print("OPHIDIAN STAFF: 12 decoded action cases, six corpse hues and seven finite-terrain handoffs")
	quit()

func preserved(actor: Node3D, kind: String, treatment: String, new_tracks: int) -> bool:
	var source := (load("res://local-art/creatures/%s-%s.gltf" % [kind, treatment]) as PackedScene).instantiate()
	var baseline := source.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var player: AnimationPlayer = actor.animator
	for label in baseline.get_animation_list():
		var before := baseline.get_animation(label)
		var after := player.get_animation(label)
		assert(before.length == after.length and before.get_track_count() + new_tracks == after.get_track_count())
		for track in before.get_track_count():
			assert(before.track_get_path(track) == after.track_get_path(track))
			assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track))
	source.free()
	return true

func check_sparks(actor: Node3D, forward: bool) -> bool:
	var player: AnimationPlayer = actor.animator
	player.advance(0.16)
	player.seek(player.current_animation_length * 0.50, true)
	actor._process(0.0)
	if actor.cast_sparks.emitting == forward or actor.release_sparks.emitting != forward:
		return false
	player.seek(player.current_animation_length * 0.90, true)
	actor._process(0.0)
	return not actor.cast_sparks.emitting and not actor.release_sparks.emitting

func check_staff(actor: Node3D, treatment: String) -> bool:
	var staff := actor.find_child(PROP, true, false) as MeshInstance3D
	assert(staff != null and staff.mesh.get_faces().size() == 186)
	assert(staff.get_active_material(0) is StandardMaterial3D)
	var rig := staff.get_parent() as Skeleton3D
	var bone := staff.skin.get_bind_bone(0)
	var grip := rig.get_bone_parent(bone)
	var left := rig.find_bone("cp_grasp_lhand")
	assert(rig.get_bone_name(grip) == "cp_grasp_rhand" and left >= 0)
	var body := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	assert(body != staff)
	var clearance := StaffClearance.new(body, rig)
	var body_skin := Ground.skin_points(body, rig)
	var staff_skin := Ground.skin_points(staff, rig)
	var player: AnimationPlayer = actor.animator
	var root_pose := actor.global_transform
	for clip: String in MOTIONS:
		player.stop()
		player.play(clip, 0.0)
		player.advance(0.0)
		var floor := INF
		var body_floor := INF
		var grip_error := 0.0
		var crossings := 0
		var brace_gap := INF
		for sample in 121:
			var phase := float(sample) / 120.0
			player.seek(player.get_animation(clip).length * phase, true)
			rig.force_update_all_bone_transforms()
			var world := rig.global_transform * rig.get_bone_global_pose(bone)
			var right_point := rig.to_global(rig.get_bone_global_pose(grip).origin)
			grip_error = maxf(grip_error, world.origin.distance_to(right_point))
			var brace: Variant = null
			if clip == "StaffCast":
				var hold := smoothstep(0.02, 0.35, phase) * (1.0 - smoothstep(0.61, 0.98, phase))
				if hold > 0.93:
					brace = rig.to_global(rig.get_bone_global_pose(left).origin)
					var point := Geometry3D.get_closest_point_to_segment(brace, world * Vector3(0, 0.16, 0), world * Vector3(0, 0.70, 0))
					brace_gap = minf(brace_gap, point.distance_to(brace))
			clearance.update_pose()
			if clearance.crosses_staff(world, 0.0, brace):
				crossings += 1
			floor = minf(floor, Ground.minimum_plane_gap(staff_skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
			body_floor = minf(body_floor, Ground.minimum_plane_gap(body_skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		print(treatment, " ", clip, " staff/body floor, grip error, shaft crossings and left brace gap ",
			[floor, body_floor, grip_error, crossings, brace_gap])
		if floor < (-0.065 if clip == "Death" else 0.004) or grip_error > 0.00001 or crossings != 0:
			return false
		if (clip in ["StaffDip", "StaffCast", "Cast2"] and body_floor < -0.005) or (clip == "StaffCast" and brace_gap > 0.055):
			return false
	return actor.global_transform.is_equal_approx(root_pose)

func check_queen(actor: Node3D) -> bool:
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	player.stop()
	player.play("OphidianQueenDip", 0.0)
	player.advance(0.0)
	var skin := Ground.skin_points(actor.model.find_children("*", "MeshInstance3D", true, false)[0], rig)
	var head := rig.find_bone("bip01 head")
	var start := rig.to_global(rig.get_bone_global_pose(head).origin).y
	var drop := 0.0
	var floor := INF
	for sample in 91:
		player.seek(player.current_animation_length * float(sample) / 90.0, true)
		rig.force_update_all_bone_transforms()
		drop = maxf(drop, start - rig.to_global(rig.get_bone_global_pose(head).origin).y)
		floor = minf(floor, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
	print("Ophidian Matriarch ", actor.treatment, " head dip and floor ", [drop, floor])
	return drop > 0.055 and floor > -0.005
