# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-bone-knight-cyclops.gd"

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/bone-knight-acid-elemental/"
const Rise := "SkeletalKnightShieldRise"
const Alert := "SkeletalKnightSwordAlert"


func run() -> void:
	var row := Registry.entry(147)
	var blade := prop_mesh("scimitar", Basis(Vector3.DOWN, Vector3.RIGHT, Vector3.BACK), .49, Vector3.ZERO)
	var shield := prop_mesh("wooden_shield", Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), 1.0, Vector3(-.098, .04, .205))
	shield_grip(shield)
	for treatment: String in Profile.registered_assets(row):
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var body := model.find_child("Body", true, false) as MeshInstance3D
		var skin := Ground.skin_points(body, rig)
		var props: Array[Dictionary] = [attach(model, rig, "Scimitar", blade, "r"),
			attach(model, rig, "WoodenShield", shield, "l")]
		var clearance := BladeClearance.new(body, rig)
		var lib := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", lib)
		for clip: String in [Rise, Alert]:
			assert(lib.add_animation(clip, fit_pose(player, rig, skin, clip)) == OK)
		Exact.check_earlier_keys(player, source)
		for clip: String in lib.get_animation_list():
			fit_clip(player, rig, clip, props, clearance)
		if not (settle_shield(player, rig, props[1], clearance) and correct_blade_recoil(player, rig, props[0], clearance)):
			model.free()
			quit(1)
			return
		player.stop()
		rig.reset_bone_poses()
		var packed := PackedScene.new()
		assert(packed.pack(model) == OK)
		assert(ResourceSaver.save(packed, Destination + "147-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("SKELETAL KNIGHT ", treatment, ": original rig, retained body motion and fitted props")
	quit()


func settle_shield(player: AnimationPlayer, rig: Skeleton3D, prop: Dictionary, clearance: RefCounted) -> bool:
	var motion := player.get_animation("Death")
	var intervals := ceili(motion.length * 540.0)
	var shape_center := Vector3(0.0, .04, .267)
	var held_basis := Basis(Vector3.UP, .52).rotated(Vector3.RIGHT, -.58).rotated(Vector3.BACK, -.45)
	var held := held_basis.get_rotation_quaternion()
	var flat := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP).rotated(Vector3.UP, .36)
	var grounded_rotation := flat.get_rotation_quaternion()
	var landing := Vector3(1.08, 0, -.43)
	var offsets := PackedVector3Array()
	var turns: Array[Quaternion] = []
	player.play("Death", 0.0)
	player.advance(0.0)
	for index in intervals + 1:
		var phase := float(index) / intervals
		player.seek(motion.length * phase, true)
		rig.force_update_all_bone_transforms()
		var socket := rig.global_transform * rig.get_bone_global_pose(prop.grip)
		var socket_rotation := socket.basis.orthonormalized().inverse()
		var attached := Transform3D(socket.basis * (socket_rotation * held_basis), socket.origin)
		var ground_basis := flat.scaled_local(socket.basis.get_scale())
		var ground_y := .012 - prop_floor(Transform3D(ground_basis, Vector3.ZERO), prop.points)
		var ground := Transform3D(ground_basis, landing + Vector3.UP * ground_y)
		# Ease the visible shield center away from the moving wrist and settle it at one world-space point.
		var progress := smoothstep(.53, .86, phase)
		var rotation := (socket_rotation * Basis(held.slerp(grounded_rotation, progress))).get_rotation_quaternion()
		var basis := socket.basis * Basis(rotation)
		var center := (attached * shape_center).lerp(ground * shape_center, progress)
		center.y += .12 * sin(PI * progress)
		var moved := Transform3D(basis, center - basis * shape_center)
		clearance.update_pose()
		if prop_floor(moved, prop.points) < .009 or clearance.crosses_prop(moved, "WoodenShield", .012 * progress):
			push_error("Skeletal Knight shield clearance failed at phase %.6f" % phase)
			return false
		offsets.append(socket.affine_inverse() * moved.origin)
		turns.append(rotation)
	player.stop()
	var path := player.get_node(player.root_node).get_path_to(rig)
	var bone_path := NodePath("%s:woodenshield" % path)
	var position_track := channel(motion, bone_path, Animation.TYPE_POSITION_3D)
	var heading_track := channel(motion, bone_path, Animation.TYPE_ROTATION_3D)
	for key in range(motion.track_get_key_count(heading_track) - 1, -1, -1):
		motion.track_remove_key(heading_track, key)
	for index in intervals + 1:
		var time := motion.length * index / intervals
		motion.position_track_insert_key(position_track, time, offsets[index])
		motion.rotation_track_insert_key(heading_track, time, turns[index])
	print("SKELETAL KNIGHT SHIELD: ", intervals + 1, " release poses to ", landing)
	return true


func correct_blade_recoil(player: AnimationPlayer, rig: Skeleton3D, prop: Dictionary, clearance: RefCounted) -> bool:
	var motion := player.get_animation("Death")
	var path := player.get_node(player.root_node).get_path_to(rig)
	var track := motion.find_track(NodePath("%s:scimitar" % path), Animation.TYPE_ROTATION_3D)
	assert(track >= 0)
	var end := .105 * motion.length
	var intervals := ceili(end * 720.0)
	var trials: Array[Dictionary] = []
	for sideways: float in [-.35, -.57, -.75, -.90, -1.18, -1.52, -2.0, -.15, .12]:
		for rise: float in [.40, .21, .60, .07, .78, 1.10, -.20, -.45]:
			var axis := Vector3(sideways, rise, 1.0).normalized()
			var heading := Quaternion(Vector3.UP, axis)
			trials.append({"heading": heading, "axis": axis, "valid": true, "turns": [], "failure": 0.0})
	player.play("Death", 0.0)
	player.advance(0.0)
	for index in intervals + 1:
		var time := end * index / intervals
		var phase := time / motion.length
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		var prop_pose := rig.global_transform * rig.get_bone_global_pose(prop.bone)
		var socket := rig.global_transform * rig.get_bone_global_pose(prop.grip)
		var inverse := socket.basis.orthonormalized().inverse()
		var taper := 1.0 - smoothstep(.046, .102, phase)
		var held := prop_pose.basis.orthonormalized().get_rotation_quaternion()
		clearance.update_pose()
		for trial: Dictionary in trials:
			if not trial.valid:
				continue
			var heading := Basis(held.slerp(trial.heading, taper))
			var rotation := (inverse * heading).get_rotation_quaternion()
			var pose := Transform3D(socket.basis * Basis(rotation), socket.origin)
			if prop_floor(pose, prop.points) < .012 or clearance.crosses_prop(pose, "Scimitar", .008 * taper):
				trial.valid = false
				trial.failure = phase
				continue
			trial.turns.append(rotation)
	player.stop()
	for trial: Dictionary in trials:
		if not trial.valid:
			continue
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			if motion.track_get_key_time(track, key) < end:
				motion.track_remove_key(track, key)
		for index in intervals + 1:
			motion.rotation_track_insert_key(track, end * index / intervals, trial.turns[index])
		print("SKELETAL KNIGHT BLADE: ", intervals + 1, " recoil poses facing ", trial.axis)
		return true
	trials.sort_custom(func(a: Dictionary, b: Dictionary): return a.failure > b.failure)
	push_error("Skeletal Knight blade recoil still crosses the body: " +
		str(trials.slice(0, 4).map(func(trial: Dictionary): return [trial.axis, trial.failure])))
	return false

func prop_floor(pose: Transform3D, points: PackedVector3Array) -> float:
	var floor := INF
	for point: Vector3 in points:
		floor = minf(floor, (pose * point).y)
	return floor

func fit_pose(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, label: String) -> Animation:
	var motion := player.get_animation("Idle").duplicate(true) as Animation
	motion.length = 1.25 if label == Rise else .65
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		for key in range(motion.track_get_key_count(track) - 1, 0, -1):
			motion.track_remove_key(track, key)
	var path := player.get_node(player.root_node).get_path_to(rig)
	var root_joint := rig.find_bone("__root")
	var placement := channel(motion, NodePath("%s:__root" % path), Animation.TYPE_POSITION_3D)
	var tracks := {}
	for joint: String in BONES + ["bip01 pelvis", "bip01 neck"]:
		tracks[rig.find_bone(joint)] = channel(motion, NodePath("%s:%s" % [path, joint]), Animation.TYPE_ROTATION_3D)
	player.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 81:
		var phase := frame / 80.0
		var time := phase * motion.length
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		choreograph(rig, label, phase)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var base := rig.get_bone_global_pose(root_joint)
		base.origin += rig.global_basis.inverse() * Vector3.UP * (.005 - gap)
		rig.set_bone_global_pose(root_joint, base)
		motion.position_track_insert_key(placement, time, rig.get_bone_pose_position(root_joint))
		for bone: int in tracks:
			motion.rotation_track_insert_key(tracks[bone], time, rig.get_bone_pose_rotation(bone))
	player.stop()
	return motion


func choreograph(rig: Skeleton3D, label: String, phase: float) -> void:
	var rise := label == Rise
	var crouch := 1.0 - smoothstep(.06, .74, phase) if rise else .32 * sin(PI * phase)
	var guard := sin(PI * clampf((phase - .13) / .78, 0.0, 1.0))
	var blade := .41 * guard if rise else .96 * smoothstep(.09, .66, phase)
	turn(rig, "bip01 pelvis", Vector3.RIGHT, .44 * crouch)
	turn(rig, "bip01 spine", Vector3.RIGHT, .57 * crouch)
	turn(rig, "bip01 spine1", Vector3.UP, -.39 * guard)
	turn(rig, "bip01 neck", Vector3.RIGHT, -.39 * crouch)
	turn(rig, "bip01 l upperarm", Vector3.RIGHT, -.60 * guard)
	turn(rig, "bip01 l upperarm", Vector3.BACK, .35 * crouch)
	turn(rig, "bip01 l forearm", Vector3.RIGHT, -.87 * crouch - .41 * guard)
	turn(rig, "bip01 r upperarm", Vector3.RIGHT, -.96 * blade)
	turn(rig, "bip01 r upperarm", Vector3.BACK, -.59 * crouch - .41 * blade)
	turn(rig, "bip01 r forearm", Vector3.RIGHT, -.55 * crouch - .47 * blade)
	for side: String in ["l", "r"]:
		var bias := 1.0 if side == "r" else .80
		turn(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -1.02 * crouch * bias)
		turn(rig, "bip01 %s calf" % side, Vector3.RIGHT, 1.72 * crouch * bias)
		turn(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.55 * crouch * bias)


func turn(rig: Skeleton3D, label: String, axis: Vector3, angle: float) -> void:
	rotate_joint(rig, rig.find_bone(label), Quaternion((rig.global_basis.inverse() * axis).normalized(), angle))


func orientation(label: String, clip: String, phase: float) -> Basis:
	if clip not in [Rise, Alert]:
		return super.orientation(label, clip, phase)
	if label == "WoodenShield":
		var brace := sin(PI * phase)
		return Basis(Vector3.UP, -.22 + .65 * brace).rotated(Vector3.RIGHT, -.09 - .20 * brace)
	var low := Vector3(-.72, .11, .68).normalized()
	var high := Vector3(-.45, .73, -.50).normalized()
	var raised := smoothstep(.13, .71, phase)
	var point := low.slerp(high, .63 * sin(PI * phase) if clip == Rise else raised)
	return Basis(Quaternion(Vector3.UP, point))
