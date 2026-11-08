extends "res://../scripts/bake-ophidian-staff-gestures.gd"

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Earlier := preload("res://../scripts/test-quadruped-actions.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const CLASSIC := {3:"Death2", 5:"StaffReel", 6:"StaffSweep", 13:"StaffFlare",
	15:"StaffFeint", 16:"StaffGuard", 18:"StaffSettle"}
const TIME := {3:1.16, 5:0.74, 6:0.86, 13:0.70, 15:0.48, 16:0.48, 18:0.75}

func run() -> void:
	var entry := Registry.entry(85)
	assert(entry.classic_action_categories["11"] == "StaffDip")
	var treatments := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(entry, treatment)
		var stem := "res://local-art/creatures/ophidian-mage-distinct-actions"
		var seed := "%s-seed-%s.scn" % [stem, treatment]
		var fitted := "%s-fitted-%s.scn" % [stem, treatment]
		var target := "%s-%s.scn" % [stem, treatment]
		bake_stage(source, seed, treatment, "body")
		bake_stage(seed, fitted, treatment, "staff")
		bake_stage(fitted, target, treatment, "smooth")
		treatments[treatment] = {"source":FileAccess.get_sha256(source), "scene":FileAccess.get_sha256(target)}
	var inputs := {}
	for file: String in ["bake-ophidian-mage-distinct-actions.gd", "bake-ophidian-staff-gestures.gd",
			"ophidian-staff-clearance.gd", "ophidian-bardiche-clearance.gd",
			"bake-skeleton-axe-trial.gd", "bake-troll-weapons-trial.gd", "test-quadruped-actions.gd"]:
		inputs[file] = FileAccess.get_sha256("res://../scripts/" + file)
	inputs["SourceGroundLookup.gd"] = FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd")
	var path := "res://local-art/creatures/ophidian-mage-distinct-actions-bake.json"
	var receipt := FileAccess.open(path, FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"inputs":inputs, "scenes":{"85":treatments}}))
	receipt.close()
	quit()

func bake_stage(source: String, target: String, treatment: String, stage: String) -> void:
	# The staff fit must use a reloaded scene so the pose cache matches normal playback.
	var scene := ResourceLoader.load(source, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var model := scene.instantiate()
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var body := model.find_child("Body", true, false) as MeshInstance3D
	var staff := model.find_child("OphidianMageStaff", true, false) as MeshInstance3D
	assert(body != null and staff != null)
	var grip := rig.find_bone("cp_grasp_rhand")
	var staff_bone := rig.find_bone(STAFF_BONE)
	assert(grip >= 0 and rig.get_bone_parent(staff_bone) == grip)
	var points := PackedVector3Array()
	for surface in staff.mesh.get_surface_count():
		points.append_array(staff.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
	var skin := Ground.skin_points(body, rig)
	var clearance := StaffClearance.new(body, rig)
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	for slot: int in CLASSIC:
		var clip: String = CLASSIC[slot]
		match stage:
			"body":
				assert(library.add_animation(clip, fit_motion(player, rig, skin, slot)) == OK)
				bake_staff(player, rig, grip, staff_bone, points, clearance, clip)
				player.stop()
				player.clear_caches()
			"staff": repair(player, rig, grip, staff_bone, points, clearance, clip, treatment)
			"smooth": smooth(player, rig, grip, points, clearance, clip)
	if stage == "body":
		Earlier.check_earlier_keys(player, source)
	player.stop()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()

func fit_motion(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, slot: int) -> Animation:
	var seed := player.get_animation("Idle")
	var motion := seed.duplicate(true) as Animation
	motion.length = TIME[slot]
	motion.loop_mode = Animation.LOOP_NONE
	for track in range(motion.get_track_count() - 1, -1, -1):
		if str(motion.track_get_path(track).get_concatenated_subnames()) == STAFF_BONE:
			motion.remove_track(track)
			continue
		for key in range(motion.track_get_key_count(track) - 1, 0, -1):
			motion.track_remove_key(track, key)
	var path := player.get_node(player.root_node).get_path_to(rig)
	var rotations := {}
	for joint: String in ["bip01", "bip01 neck"] + BODY_JOINTS + ARM_JOINTS:
		var label := NodePath("%s:%s" % [path, joint])
		var track := motion.find_track(label, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(track, label)
		rotations[rig.find_bone(joint)] = track
	var root_track := motion.find_track(NodePath("%s:bip01" % path), Animation.TYPE_POSITION_3D)
	if root_track < 0:
		root_track = motion.add_track(Animation.TYPE_POSITION_3D)
		motion.track_set_path(root_track, NodePath("%s:bip01" % path))
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 121:
		var phase := frame / 120.0
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		choreograph(rig, slot, phase)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var joint := rig.find_bone("bip01")
		var pose := rig.get_bone_global_pose(joint)
		pose.origin += rig.global_basis.inverse() * Vector3.UP * (0.004 - gap)
		rig.set_bone_global_pose(joint, pose)
		var time := motion.length * phase
		motion.position_track_insert_key(root_track, time, rig.get_bone_pose_position(joint))
		for bone: int in rotations:
			motion.rotation_track_insert_key(rotations[bone], time, rig.get_bone_pose_rotation(bone))
	return motion

func choreograph(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.04, 0.44, phase) * (1.0 - smoothstep(0.58, 1.0, phase))
	match slot:
		3:
			var down := smoothstep(0.20, 0.91, phase)
			var drop := 0.96 * down
			turn(rig, "bip01 spine", Vector3.RIGHT, 0.38 * down)
			turn(rig, "bip01 spine1", Vector3.RIGHT, drop)
			turn(rig, "bip01 spine2", Vector3.FORWARD, 0.63 * down)
			turn(rig, "bip01 tail1", Vector3.UP, 0.42 * down)
			turn(rig, "bip01 r upperarm", Vector3.RIGHT, -0.47 * pulse)
			turn(rig, "bip01 l upperarm", Vector3.RIGHT, -0.51 * down)
		5:
			turn(rig, "bip01 spine1", Vector3.RIGHT, -0.63 * pulse)
			turn(rig, "bip01 r upperarm", Vector3.RIGHT, -1.05 * pulse)
			turn(rig, "bip01 tail1", Vector3.UP, 0.26 * pulse)
		6:
			var swing := smoothstep(0.17, 0.52, phase) * (1.0 - smoothstep(0.70, 1.0, phase))
			turn(rig, "bip01 spine1", Vector3.RIGHT, 0.73 * swing)
			turn(rig, "bip01 spine2", Vector3.UP, -0.46 * pulse)
			turn(rig, "bip01 r upperarm", Vector3.RIGHT, -0.47 * swing)
			turn(rig, "bip01 r forearm", Vector3.UP, 0.62 * swing)
		13:
			turn(rig, "bip01 r upperarm", Vector3.RIGHT, -1.38 * pulse)
			turn(rig, "bip01 r forearm", Vector3.RIGHT, -0.31 * pulse)
			turn(rig, "bip01 l upperarm", Vector3.RIGHT, -0.55 * pulse)
			turn(rig, "bip01 head", Vector3.RIGHT, -0.20 * pulse)
		15:
			turn(rig, "bip01 spine2", Vector3.RIGHT, 0.46 * pulse)
			turn(rig, "bip01 r upperarm", Vector3.RIGHT, -0.40 * pulse)
		16:
			turn(rig, "bip01 r upperarm", Vector3.RIGHT, -0.81 * pulse)
			turn(rig, "bip01 l forearm", Vector3.RIGHT, -0.70 * pulse)
			turn(rig, "bip01 spine2", Vector3.UP, 0.28 * pulse)
		18:
			turn(rig, "bip01 head", Vector3.UP, -0.16 * pulse)
			turn(rig, "bip01 tail1", Vector3.UP, -0.14 * pulse)

func turn(rig: Skeleton3D, joint: String, axis: Vector3, angle: float) -> void:
	rotate_joint(rig, rig.find_bone(joint), Quaternion((rig.global_basis.inverse() * axis).normalized(), angle))

func staff_direction(rig: Skeleton3D, socket: Transform3D, label: String, phase: float) -> Vector3:
	var desired := super.staff_direction(rig, socket, label, phase)
	var pulse := smoothstep(0.08, 0.44, phase) * (1.0 - smoothstep(0.61, 1.0, phase))
	var target: Vector3 = {
		"Death2": Vector3(-0.60, 0.30, 0.74), "StaffReel":Vector3(-0.35, 0.78, 0.52),
		"StaffSweep":Vector3(-0.25, 0.18, 0.95), "StaffFlare":Vector3(-0.42, 0.85, 0.31),
		"StaffFeint":Vector3(-0.64, 0.31, 0.71), "StaffGuard":Vector3(-0.38, 0.90, 0.18),
		"StaffSettle":Vector3(-0.41, 0.78, 0.47),
	}[label]
	var blend := smoothstep(0.16, 0.91, phase) if label == "Death2" else pulse
	return desired.slerp(target.normalized(), blend)

func repair(player: AnimationPlayer, rig: Skeleton3D, grip: int, staff: int, points: PackedVector3Array,
		clearance: RefCounted, clip: String, treatment: String) -> void:
	var motion := player.get_animation(clip)
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var track := motion.find_track(NodePath("%s:%s" % [rig_path, STAFF_BONE]), Animation.TYPE_ROTATION_3D)
	assert(track >= 0)
	var duration := motion.length
	var intervals := ceili(duration * 240.0)
	var rotations: Array[Quaternion] = []
	var previous := Basis.IDENTITY
	var changed := 0
	var failed := 0
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	for sample in intervals + 1:
		var time := duration * sample / intervals
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		var socket := rig.global_transform * rig.get_bone_global_pose(grip)
		var prop := rig.global_transform * rig.get_bone_global_pose(staff)
		var original := motion.rotation_track_interpolate(track, time)
		clearance.update_pose()
		if not clearance.crosses_staff(prop, 0.025) and floor_gap(prop, points) >= 0.009:
			rotations.append(original)
			previous = prop.basis
			continue
		changed += 1
		var desired := Transform3D(prop.basis.orthonormalized().scaled_local(socket.basis.get_scale()), socket.origin)
		var target := fit_staff(desired, socket, previous if sample > 0 else desired.basis, points, clearance, null, 0.01)
		previous = target.basis
		var rotation := staff_local_rotation(socket, target.basis)
		var actual := Transform3D(socket.basis * Basis(rotation), socket.origin)
		if clearance.crosses_staff(actual) or floor_gap(actual, points) < 0.007:
			failed += 1
		rotations.append(rotation)
	player.stop()
	write_staff_rotations(motion, track, rotations)
	print(treatment, " ", clip, " adjusted ", changed, " / ", rotations.size(), " unresolved ", failed)
	assert(failed == 0)

func smooth(player: AnimationPlayer, rig: Skeleton3D, grip: int, points: PackedVector3Array,
		clearance: RefCounted, clip: String) -> void:
	var motion := player.get_animation(clip)
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var track := motion.find_track(NodePath("%s:%s" % [rig_path, STAFF_BONE]), Animation.TYPE_ROTATION_3D)
	assert(track >= 0)
	var duration := motion.length
	var intervals := ceili(duration * 240.0)
	var rotations: Array[Quaternion] = []
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	for sample in intervals + 1:
		rotations.append(motion.rotation_track_interpolate(track, duration * sample / intervals))
	for radius: int in [16, 12, 8, 6, 4, 3]:
		var filtered := rotations.duplicate()
		for sample in rotations.size():
			var center := rotations[sample]
			var total := center
			for offset in range(-radius, radius + 1):
				if offset == 0:
					continue
				var other := rotations[clampi(sample + offset, 0, rotations.size() - 1)]
				if center.dot(other) < 0.0:
					other = -other
				total += other * (1.0 - absf(float(offset)) / float(radius + 1))
			var target := total.normalized()
			player.seek(duration * sample / intervals, true)
			rig.force_update_all_bone_transforms()
			var socket := rig.global_transform * rig.get_bone_global_pose(grip)
			clearance.update_pose()
			for weight: float in [1.0, 0.60, 0.30, 0.15]:
				var candidate := center.slerp(target, weight)
				var pose := Transform3D(socket.basis * Basis(candidate), socket.origin)
				if floor_gap(pose, points) >= 0.008 and not clearance.crosses_staff(pose, 0.008):
					filtered[sample] = candidate
					break
		rotations = filtered
	player.stop()
	write_staff_rotations(motion, track, rotations)

func write_staff_rotations(motion: Animation, track: int, rotations: Array[Quaternion]) -> void:
	for key in range(motion.track_get_key_count(track) - 1, -1, -1):
		motion.track_remove_key(track, key)
	for sample in rotations.size():
		motion.rotation_track_insert_key(track, motion.length * sample / (rotations.size() - 1), rotations[sample])
