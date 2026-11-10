# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/golem-sand-vortex/juka-review/"
const LordClips := {23: "JukaLordStandFromCrouch", 26: "JukaLordHandSignal", 27: "JukaLordForwardWatch", 28: "JukaLordStepAlert"}
const LordLengths := {23: 1.04, 26: .97, 27: .94, 28: .68}
const LordJoints := ["bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]


func run() -> void:
	prepare_body(766, LordClips, LordLengths, LordJoints, pose_lord, Destination)
	quit()


func pose_lord(rig: Skeleton3D, phase: float, group: int) -> void:
	var crouch := 0.0
	var signal_hand := 0.0
	var step := 0.0
	var look := 0.0
	var reach := 0.0
	match group:
		23:
			crouch = .84 * (1.0 - smoothstep(.10, .67, phase))
			reach = .25 * crouch
		26:
			signal_hand = .84 * envelope(phase, .01, .28, .54, .98)
			look = .25 * sin(PI * phase)
		27:
			step = .75 * smoothstep(.03, .28, phase)
			crouch = .32 + .08 * sin(TAU * phase)
			reach = .51 * step
			look = -.20 * step
		28:
			step = .81 * smoothstep(.16, .87, phase)
			look = -.28 * step
			reach = .38 * step
	var right_ankle := rig.get_bone_global_pose(rig.find_bone("bip01 r foot"))
	var left_ankle := rig.get_bone_global_pose(rig.find_bone("bip01 l foot"))
	right_ankle.origin += rig.global_basis.inverse() * Vector3(-.13 * step, .09 * sin(PI * step), .43 * step)
	left_ankle.origin += rig.global_basis.inverse() * Vector3(.03 * step, .04 * step, -.22 * step)
	var pelvis := rig.find_bone(RootJoint)
	var hips := rig.get_bone_global_pose(pelvis)
	hips.origin += rig.global_basis.inverse() * Vector3(-.064 * step, -.45 * crouch, .21 * step)
	rig.set_bone_global_pose(pelvis, hips)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .33 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .28 * crouch)
	turn_world(rig, "bip01 spine2", Vector3.UP, .63 * look)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.31 * crouch)
	turn_world(rig, "bip01 head", Vector3.UP, .46 * look)
	fit_foot(rig, "r", right_ankle)
	fit_foot(rig, "l", left_ankle)
	var chest := joint_world(rig, "bip01 spine2")
	var right := joint_world(rig, "bip01 r hand")
	var left := joint_world(rig, "bip01 l hand")
	fit_arm(rig, "r", right.lerp(chest + Vector3(-.46, .31, .35), signal_hand)
		.lerp(chest + Vector3(-.48, -.46, .61), reach))
	fit_arm(rig, "l", left.lerp(chest + Vector3(.53, -.38, .45), .62 * step + .21 * crouch))
	turn_world(rig, "bip01 r hand", Vector3.BACK, -.30 * signal_hand)
