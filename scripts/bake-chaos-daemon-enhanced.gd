# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/chaos-daemon-enhanced/"
const Clips := {11: "ChaosDaemonLowHunch", 12: "ChaosDaemonClawInvocation", 15: "ChaosDaemonHighGuard",
	23: "ChaosDaemonCrouchingRise", 25: "ChaosDaemonQuietBreath", 26: "ChaosDaemonWatch",
	27: "ChaosDaemonWideThreat", 28: "ChaosDaemonCombatSet"}
const Durations := {11: .91, 12: 1.01, 15: .81, 23: 1.13, 25: 1.18, 26: 1.02, 27: .94, 28: 1.05}
const DaemonJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l clavicle", "bip01 r clavicle", "bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm",
	"bip01 l hand", "bip01 r hand", "bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf",
	"bip01 l horselink", "bip01 r horselink", "bip01 l foot", "bip01 r foot"]


func run() -> void:
	prepare_body(792, Clips, Durations, DaemonJoints, pose_daemon, Destination, configure_motion)
	quit()


func configure_motion(clip: Animation, _rig: Skeleton3D, group: int) -> void:
	if group == 25:
		clip.loop_mode = Animation.LOOP_LINEAR


func pose_daemon(rig: Skeleton3D, phase: float, group: int) -> void:
	var crouch := 0.0
	var guard := 0.0
	var strike := 0.0
	var spread := 0.0
	var yaw := 0.0
	var upright := 0.0
	match group:
		11:
			crouch = .52 * envelope(phase, .02, .33, .66, .98)
			yaw = .26 * sin(TAU * phase) * crouch
			spread = .13 * crouch
		12:
			guard = .91 * envelope(phase, .05, .30, .54, .92)
			strike = .89 * envelope(phase, .33, .58, .70, 1.0)
			spread = .31 * guard
			crouch = .24 * strike
		15:
			guard = .80 * envelope(phase, .03, .34, .63, .98)
			strike = .38 * guard
			crouch = .21 * guard
			spread = .26 * guard
		23:
			crouch = .97 * (1.0 - smoothstep(.05, .72, phase))
			spread = .46 * envelope(phase, .13, .52, .65, 1.0)
			yaw = .24 * sin(TAU * phase)
			upright = .84 * smoothstep(.22, .91, phase)
		25:
			spread = .027 * (1.0 - cos(TAU * phase))
			yaw = .021 * sin(TAU * phase)
			upright = .60
			crouch = .018 * (1.0 - cos(TAU * phase))
		26:
			var watch := envelope(phase, .06, .33, .69, .99)
			yaw = .39 * watch
			upright = .53 + .10 * watch
			guard = .09 * watch
			crouch = .11 * watch
		27:
			spread = 1.17 * envelope(phase, .05, .37, .66, .99)
			guard = .34 * spread
			crouch = .32 * (1.0 - smoothstep(.22, .67, phase)) + .14 * spread
			yaw = .13 * sin(TAU * phase) * spread
		28:
			crouch = .44 * smoothstep(.10, .78, phase)
			spread = .29 * crouch
			strike = .35 * crouch
	var feet := {}
	for side: String in ["l", "r"]:
		feet[side] = joint_world(rig, "bip01 %s foot" % side)
	turn_world(rig, RootJoint, Vector3.RIGHT, .27 * crouch - .16 * upright)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .24 * crouch - .13 * guard - .33 * upright)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, .19 * crouch - .16 * guard - .39 * upright)
	turn_world(rig, "bip01 spine2", Vector3.UP, .41 * yaw)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.34 * crouch + .17 * guard + .24 * upright)
	turn_world(rig, "bip01 head", Vector3.UP, .59 * yaw)
	var pelvis := rig.find_bone(RootJoint)
	var placement := rig.get_bone_global_pose(pelvis)
	placement.origin += rig.global_basis.inverse() * Vector3(0.0, -.29 * crouch + .11 * upright, -.17 * crouch)
	rig.set_bone_global_pose(pelvis, placement)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var lead := 1.0 if side == "l" else .82
		turn_world(rig, "bip01 %s clavicle" % side, Vector3.BACK, sign_x * .10 * spread)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign_x * (.99 * spread + .21 * guard + .92 * crouch))
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -lead * (.78 * guard + .63 * strike + .47 * crouch) + .20 * upright)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.62 * guard + .52 * strike - .56 * crouch)
		turn_world(rig, "bip01 %s hand" % side, Vector3.UP, sign_x * (.26 * spread - .17 * guard))
		turn_world(rig, "bip01 %s horselink" % side, Vector3.RIGHT, -.21 * crouch)
		plant_foot(rig, side, feet[side])


func plant_foot(rig: Skeleton3D, side: String, target: Vector3) -> void:
	var thigh := rig.find_bone("bip01 %s thigh" % side)
	var knee := rig.find_bone("bip01 %s calf" % side)
	var foot := rig.find_bone("bip01 %s foot" % side)
	var ankle_basis := rig.get_bone_global_pose(foot).basis
	var hip := rig.get_bone_global_pose(thigh).origin
	var bend := rig.get_bone_global_pose(knee).origin
	var ankle := rig.get_bone_global_pose(foot).origin
	var goal := rig.to_local(target)
	var direction := (goal - hip).normalized()
	var upper := hip.distance_to(bend)
	var lower := bend.distance_to(ankle)
	var reach := clampf(hip.distance_to(goal), absf(upper - lower) + .001, upper + lower - .001)
	var along := (upper * upper - lower * lower + reach * reach) / (2.0 * reach)
	var outward := (bend - hip).slide(direction).normalized()
	var knee_goal := hip + direction * along + outward * sqrt(maxf(0.0, upper * upper - along * along))
	aim_daemon_limb(rig, thigh, knee, knee_goal)
	aim_daemon_limb(rig, knee, foot, hip + direction * reach)
	var restored := rig.get_bone_global_pose(foot)
	restored.basis = ankle_basis
	rig.set_bone_global_pose(foot, restored)
	rig.force_update_all_bone_transforms()


func aim_daemon_limb(rig: Skeleton3D, joint: int, landmark: int, target: Vector3) -> void:
	var pose := rig.get_bone_global_pose(joint)
	var current := (rig.get_bone_global_pose(landmark).origin - pose.origin).normalized()
	var desired := (target - pose.origin).normalized()
	pose.basis = Basis(Quaternion(current, desired)) * pose.basis
	rig.set_bone_global_pose(joint, pose)
	rig.force_update_all_bone_transforms()
