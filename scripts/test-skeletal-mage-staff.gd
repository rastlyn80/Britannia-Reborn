extends "res://../scripts/test-troll-weapon-trial.gd"

const MAGE := 148
const STAFF := "SkeletonMageStaff"
const CHECK := "MageStaffCheck"
const Clearance := preload("res://../scripts/skeletal-mage-staff-clearance.gd")
const FINGER_TRACKS := ["bip01 r finger0", "bip01 r finger01", "bip01 r finger1", "bip01 r finger11"]
const MOTION := ["Idle", "Walk", "Run", "Attack", "Hit", "Fidget", CHECK, "Death", "Death2"]

func _initialize() -> void:
	create_timer(60.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	if not "--active" in OS.get_cmdline_user_args():
		var path := "res://../work/creatures/skeletal_mage_staff/candidates.json"
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		Registry.load_index()
		for row: Dictionary in rows:
			Registry.entries[int(row.body)] = row.presentation
	var entry := Registry.entry(MAGE)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var serial := 0x4148
	game.entities[serial] = {"serial": serial, "body": MAGE, "hue": 0x8035}
	for treatment: String in ["original", "rounded", "modern"]:
		assert(FileAccess.get_sha256(entry.assets[treatment]) == entry.authored_action_scene_sha256[treatment])
		var actor := Registry.create(MAGE)
		actor.treatment = treatment
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.apply_identity(MAGE, 0x8035)
		for group: int in [11, 17, 4]:
			var packet := PackedByteArray([0x6e])
			packet.append_array(Wire.uint_be(serial, 4))
			packet.append_array(PackedByteArray([0, group, 0, 5, 0, 1, 1, 0, 0]))
			game._handle(packet)
			assert(actor.receive_action(game.last_mobile_actions[serial]))
			assert(actor.current_clip == {11: CHECK, 17: "Fidget", 4: "Attack"}[group])
		assert(check_source_tracks(actor.animator, treatment))
		assert(check_staff_motion(actor, treatment))
		actor.free()
	for hue: int in [0, 53, 0x8035]:
		check_corpse(MAGE, hue, STAFF)
	await check_handoff(MAGE, STAFF, Vector3.RIGHT, 0.0)
	for axis in [Vector3.RIGHT, Vector3.FORWARD]:
		for slope in [-0.14, 0.14]:
			await check_handoff(MAGE, STAFF, axis, slope)
	await check_handoff(MAGE, STAFF, Vector3.RIGHT, 0.0, 0.35)
	await check_handoff(MAGE, STAFF, Vector3.RIGHT, 0.0, -0.35)
	game.free()
	print("SKELETAL MAGE STAFF: nine decoded actions, three corpse hues and seven terrain handoffs")
	quit()

func check_source_tracks(player: AnimationPlayer, treatment: String) -> bool:
	var path := "res://local-art/creatures/skeletons_skeleton_mage-%s.gltf" % treatment
	var base := (load(path) as PackedScene).instantiate()
	var original := base.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip in original.get_animation_list():
		var before := original.get_animation(clip)
		var after := player.get_animation(clip)
		assert(before.length == after.length)
		for track in before.get_track_count():
			var node := before.track_get_path(track)
			assert(node == after.track_get_path(track))
			if clip not in ["Death", "Death2", "RESET"] and before.track_get_type(track) == Animation.TYPE_ROTATION_3D \
					and str(node.get_concatenated_subnames()) in FINGER_TRACKS:
				continue
			assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track))
	base.free()
	return true

func check_staff_motion(actor: Node3D, treatment: String) -> bool:
	var player: AnimationPlayer = actor.animator
	var staff := actor.find_child(STAFF, true, false) as MeshInstance3D
	assert(staff != null and staff.mesh.get_faces().size() == 54)
	assert(staff.get_active_material(0) == staff.mesh.surface_get_material(0))
	var rig := staff.get_parent() as Skeleton3D
	var joint := staff.skin.get_bind_bone(0)
	var grip := rig.get_bone_parent(joint)
	assert(rig.get_bone_name(grip) == "cp_grasp_rhand")
	var body := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var clearance := Clearance.new(body, rig)
	var staff_skin := Ground.skin_points(staff, rig)
	var neck := rig.find_bone("bip01 head")
	var initial_position := actor.global_position
	for clip: String in MOTION:
		player.stop()
		player.play(clip, 0.0)
		player.advance(0.0)
		rig.force_update_all_bone_transforms()
		var initial := rig.get_bone_pose_rotation(neck)
		var head_angle := 0.0
		var floor := INF
		var crossing := 0
		var grip_error := 0.0
		for sample in 159:
			var phase := clampf((float(sample) - 0.37) / 157.0, 0.0, 1.0)
			player.seek(player.get_animation(clip).length * phase, true)
			rig.force_update_all_bone_transforms()
			var pose := rig.get_bone_global_pose(joint)
			var center := rig.get_bone_global_pose(grip).origin
			var gap := rig.to_global(pose.origin).distance_to(rig.to_global(center))
			if clip != "Death" or phase <= 0.70:
				grip_error = maxf(grip_error, gap)
			if clip == "Death" and phase == 1.0:
				assert(gap > 0.60)
			head_angle = maxf(head_angle, initial.angle_to(rig.get_bone_pose_rotation(neck)))
			clearance.update_pose()
			crossing += int(clearance.crosses_staff(rig.global_transform * pose))
			floor = minf(floor, Ground.minimum_plane_gap(staff_skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		print(treatment, " ", clip, " staff floor/crossings/grip gap/head motion ", [floor, crossing, grip_error, head_angle])
		if crossing != 0 or grip_error > 0.0001 or floor < (-0.018 if clip in ["Death", "Death2"] else 0.20):
			return false
		if clip == CHECK and (head_angle < 0.045 or head_angle > 0.062):
			return false
	return actor.global_position.is_equal_approx(initial_position)
