# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/golem-sand-vortex/"
const Clips := {12: "IronGolemPistonSweep", 23: "IronGolemWindUp", 26: "IronGolemValveCheck",
	27: "IronGolemHammerLift", 28: "IronGolemTurnAlert"}
const Lengths := {12: .97, 23: 1.13, 26: .98, 27: 1.06, 28: .81}
const GolemJoints := ["bip01 spine", "bip01 spine1", "bip01 neck", "bone_head", "bone_stem", "bone_stem01",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]


func run() -> void:
	prepare_body(752, Clips, Lengths, GolemJoints, pose_iron, Destination)
	quit()


func pose_iron(rig: Skeleton3D, phase: float, group: int) -> void:
	var drop := 0.0
	var yaw := 0.0
	var incline := 0.0
	var wind := 0.0
	var strike := 0.0
	var lift := 0.0
	var step := 0.0
	match group:
		12:
			wind = envelope(phase, .03, .23, .38, .63)
			strike = envelope(phase, .32, .57, .72, .99)
			drop = .30 * wind + .19 * strike
			yaw = -.39 * wind + .50 * strike
			incline = .22 * wind - .11 * strike
			step = .82 * envelope(phase, .33, .55, .68, .99)
		23:
			wind = 1.0 - smoothstep(.08, .75, phase)
			drop = .52 * wind
			yaw = .23 * wind
			incline = .34 * wind
		26:
			wind = .21 * envelope(phase, .12, .38, .66, .95)
			yaw = .12 * sin(TAU * phase) * sin(PI * phase)
			incline = .06 * sin(PI * phase)
		27:
			lift = envelope(phase, .03, .28, .40, .66)
			strike = .60 * envelope(phase, .41, .56, .68, .90)
			drop = .16 * lift + .26 * strike
			yaw = .32 * lift - .15 * strike
			incline = -.12 * lift + .19 * strike
			step = .68 * lift
		28:
			strike = .59 * smoothstep(.22, .78, phase)
			yaw = -.40 * strike
			incline = .09 * strike
			step = .52 * smoothstep(.20, .84, phase)
	var left_ankle := rig.get_bone_global_pose(rig.find_bone("bip01 l foot"))
	var right_ankle := rig.get_bone_global_pose(rig.find_bone("bip01 r foot"))
	left_ankle.origin += rig.global_basis.inverse() * Vector3(.26 * step, .34 * lift + .15 * sin(PI * step), .43 * step)
	var pelvis := rig.find_bone(RootJoint)
	var hips := rig.get_bone_global_pose(pelvis)
	hips.origin += rig.global_basis.inverse() * Vector3(.21 * step, -drop, .13 * strike)
	rig.set_bone_global_pose(pelvis, hips)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .52 * incline)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .48 * incline)
	turn_world(rig, "bip01 spine1", Vector3.UP, yaw)
	turn_world(rig, "bip01 neck", Vector3.UP, -.44 * yaw)
	turn_world(rig, "bone_head", Vector3.RIGHT, -.24 * incline)
	turn_world(rig, "bone_stem", Vector3.BACK, .05 * wind - .08 * lift)
	turn_world(rig, "bone_stem01", Vector3.RIGHT, -.09 * strike)
	fit_foot(rig, "l", left_ankle)
	fit_foot(rig, "r", right_ankle)
	var chest := joint_world(rig, "bip01 spine1")
	var left := joint_world(rig, "bip01 l hand")
	var right := joint_world(rig, "bip01 r hand")
	fit_arm(rig, "l", left.lerp(chest + Vector3(1.34, .42, .70), .77 * wind)
		.lerp(chest + Vector3(1.54, .15, 1.13), .88 * strike))
	fit_arm(rig, "r", right.lerp(chest + Vector3(-1.47, .36, .78), .58 * wind)
		.lerp(chest + Vector3(-1.09, 1.69, .53), .88 * lift)
		.lerp(chest + Vector3(-1.31, .33, 1.12), .73 * strike))
	turn_world(rig, "bip01 l hand", Vector3.UP, .20 * strike)
	turn_world(rig, "bip01 r hand", Vector3.BACK, -.28 * lift)
