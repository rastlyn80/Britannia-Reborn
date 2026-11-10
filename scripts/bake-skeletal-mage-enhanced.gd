# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-skeletal-mage-staff.gd"

const MageStage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/chicken-skeletal-mage/"
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const MageClips := {12: "SkeletalMageStaffThrust", 23: "SkeletalMageGroundRise", 26: "SkeletalMageWatch",
	27: "SkeletalMageStaffLift", 28: "SkeletalMageStaffWard"}
const MageLengths := {12: .83, 23: 1.07, 26: .87, 27: .93, 28: .72}
const PoseJoints := ["bip01", "bip01 spine", "bip01 spine1", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]

func run() -> void:
	var row := Registry.entry(148)
	for treatment: String in row.assets:
		bake_mage(treatment, row)
	quit()

func bake_mage(treatment: String, row: Dictionary) -> void:
	var source := Registry.asset_path(row, treatment)
	assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var body := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var prop := model.find_child("SkeletonMageStaff", true, false) as MeshInstance3D
	assert(prop != null and prop.mesh != null)
	var points := PackedVector3Array()
	for surface in prop.mesh.get_surface_count():
		points.append_array(prop.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
	var grip := rig.find_bone("cp_grasp_rhand")
	var staff := rig.find_bone("skeletal mage staff")
	assert(grip >= 0 and staff >= 0 and points.size() >= 9)
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var skin := Ground.skin_points(body, rig)
	var clearance := Clearance.new(body, rig)
	var fingers := measure_fingers(body, rig)
	for group: int in MageClips:
		var name: String = MageClips[group]
		assert(library.add_animation(name, fit_body(player, rig, skin, group)) == OK)
		fit_clip(player, rig, grip, staff, points, clearance, name)
		close_grip(player, rig, staff, fingers, name)
		print("SKELETAL MAGE ENHANCED ", treatment, " ", name, ": body, shaft and finger chains fitted")
	player.stop()
	rig.reset_bone_poses()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed, MageStage + "148-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()

func fit_body(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, group: int) -> Animation:
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	clip.length = MageLengths[group]
	clip.loop_mode = Animation.LOOP_NONE
	for track in clip.get_track_count():
		for key in range(clip.track_get_key_count(track) - 1, 0, -1):
			clip.track_remove_key(track, key)
	var rotations := {}
	for name: String in PoseJoints:
		var joint := rig.find_bone(name)
		assert(joint >= 0)
		rotations[joint] = channel(clip, joint_path(player, rig, joint), Animation.TYPE_ROTATION_3D)
		clear_keys(clip, rotations[joint])
	var root_joint := rig.find_bone("__root")
	assert(root_joint >= 0)
	var placement := channel(clip, joint_path(player, rig, root_joint), Animation.TYPE_POSITION_3D)
	clear_keys(clip, placement)
	player.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 81:
		var phase := float(frame) / 80.0
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		pose_mage(rig, phase, group)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		assert(is_finite(gap))
		var body := rig.get_bone_global_pose(root_joint)
		body.origin += rig.global_basis.inverse() * Vector3.UP * (.004 - gap)
		rig.set_bone_global_pose(root_joint, body)
		var time := phase * clip.length
		clip.position_track_insert_key(placement, time, rig.get_bone_pose_position(root_joint))
		for joint: int in rotations:
			clip.rotation_track_insert_key(rotations[joint], time, rig.get_bone_pose_rotation(joint))
	return clip

func pose_mage(rig: Skeleton3D, phase: float, group: int) -> void:
	var bend := 0.0
	var coil := 0.0
	var reach := 0.0
	var lift := 0.0
	var turn := 0.0
	var pulse := gesture_strength(phase)
	match group:
		12:
			reach = smoothstep(.26, .53, phase) * (1.0 - smoothstep(.78, .98, phase))
			bend = .31 * reach
			turn = .30 * pulse
		23:
			coil = 1.0 - smoothstep(.18, .71, phase)
			bend = .58 * coil
			lift = .33 * gesture_strength(phase)
		26:
			bend = .10 * pulse
			turn = .15 * sin(TAU * phase) * pulse
		27:
			bend = .20 * (1.0 - smoothstep(.25, .72, phase)) * pulse
			lift = .79 * pulse
		28:
			reach = .65 * smoothstep(.10, .53, phase)
			turn = -.39 * reach
			bend = .26 * reach
	turn_mage(rig, "bip01", Vector3.RIGHT, .91 * coil + .29 * bend)
	turn_mage(rig, "bip01 spine", Vector3.RIGHT, .31 * bend)
	turn_mage(rig, "bip01 spine1", Vector3.UP, turn)
	turn_mage(rig, "bip01 head", Vector3.RIGHT, -.32 * coil - .25 * bend)
	turn_mage(rig, "bip01 r upperarm", Vector3.RIGHT, -1.02 * reach - 1.14 * lift + .29 * coil)
	turn_mage(rig, "bip01 r forearm", Vector3.RIGHT, -.55 * reach - .81 * lift)
	turn_mage(rig, "bip01 l upperarm", Vector3.BACK, .82 * reach + .65 * lift)
	turn_mage(rig, "bip01 l forearm", Vector3.RIGHT, -.91 * reach)
	for side: String in ["l", "r"]:
		turn_mage(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.93 * coil - .27 * bend)
		turn_mage(rig, "bip01 %s calf" % side, Vector3.RIGHT, .95 * coil + .37 * bend)
		turn_mage(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.47 * coil - .22 * bend)

func turn_mage(rig: Skeleton3D, name: String, axis: Vector3, angle: float) -> void:
	var joint := rig.find_bone(name)
	var pose := rig.get_bone_global_pose(joint)
	pose.basis = Basis(Quaternion((rig.global_basis.inverse() * axis).normalized(), angle)) * pose.basis
	rig.set_bone_global_pose(joint, pose)
	rig.force_update_all_bone_transforms()

func staff_direction(rig: Skeleton3D, socket: Transform3D, label: String, phase: float) -> Vector3:
	var upright := super.staff_direction(rig, socket, label, phase)
	var aim: Vector3 = {
		"SkeletalMageStaffThrust": Vector3(-.30, .10, 1.0),
		"SkeletalMageGroundRise": Vector3(-.58, .12, .81),
		"SkeletalMageStaffLift": Vector3(-.44, .98, .20),
		"SkeletalMageStaffWard": Vector3(-.67, .36, .65),
	}.get(label, upright)
	return upright.slerp(aim.normalized(), gesture_strength(phase))
