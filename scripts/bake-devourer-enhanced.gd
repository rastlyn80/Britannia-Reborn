# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/devourer-enhanced/"
const Clips := {
	11: "DevourerFoldIn", 12: "DevourerRaisedCast", 15: "DevourerGuardedBite", 23: "DevourerWakeUnfold",
	25: "DevourerQuietMaw", 26: "DevourerLowInspection", 27: "DevourerMawThreat", 28: "DevourerWideGuard",
}
const Lengths := {11: 1.10, 12: 1.24, 15: .77, 23: 1.18, 25: 1.17, 26: 1.0, 27: 1.16, 28: .96}
const RibGroups := [["bone_lrip01", "bone_lrip04", "bone_lrip06", "bone_lrip07"],
	["bone_lrip08", "bone_lrip09", "bone_lrip10", "bone_lrip11"]]
const DevourerJoints := ["bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot",
	"bonel01", "boner01"]


func run() -> void:
	prepare_body(303, Clips, Lengths, DevourerJoints + RibGroups[0] + RibGroups[1], pose_devourer, Destination)
	quit()


func pose_devourer(rig: Skeleton3D, phase: float, group: int) -> void:
	var fold := 0.0
	var high := 0.0
	var wide := 0.0
	var maw := 0.0
	var yaw := 0.0
	match group:
		11:
			fold = envelope(phase, .06, .41, .64, .98)
			maw = -.42 * fold
			yaw = .18 * sin(TAU * phase) * fold
		12:
			high = envelope(phase, .05, .30, .49, .78)
			wide = .63 * high
			fold = .60 * envelope(phase, .52, .72, .85, 1.0)
			maw = .82 * high + .30 * fold
		15:
			fold = .52 * (1.0 - smoothstep(.53, .97, phase))
			maw = .65 * envelope(phase, .09, .33, .56, .92)
			yaw = -.31 * maw
		23:
			fold = 1.0 - smoothstep(.20, .79, phase)
			wide = .82 * smoothstep(.26, .85, phase)
			maw = .60 * wide - .43 * fold
		25:
			maw = .055 * sin(TAU * phase)
			yaw = .026 * sin(TAU * phase)
		26:
			fold = .43 * envelope(phase, .08, .35, .68, .97)
			yaw = .37 * sin(TAU * phase) * sin(PI * phase)
			maw = .28 * fold
		27:
			fold = .58 * envelope(phase, .02, .23, .30, .56)
			wide = envelope(phase, .28, .52, .72, .98)
			high = .48 * wide
			maw = wide
		28:
			wide = smoothstep(.08, .70, phase)
			high = .31 * wide
			maw = .47 * wide
	var right_ankle := rig.get_bone_global_pose(rig.find_bone("bip01 r foot"))
	var left_ankle := rig.get_bone_global_pose(rig.find_bone("bip01 l foot"))
	var pelvis := rig.find_bone(RootJoint)
	var hips := rig.get_bone_global_pose(pelvis)
	hips.origin += rig.global_basis.inverse() * Vector3(.06 * yaw, -.43 * fold + .09 * high, .14 * fold)
	rig.set_bone_global_pose(pelvis, hips)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .26 * fold - .27 * high)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .50 * fold - .45 * high)
	turn_world(rig, "bip01 spine2", Vector3.UP, .57 * yaw)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.16 * fold - .27 * maw)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.19 * fold + .15 * maw)
	turn_world(rig, "bip01 head", Vector3.UP, .48 * yaw)
	fit_foot(rig, "l", left_ankle)
	fit_foot(rig, "r", right_ankle)
	var chest := joint_world(rig, "bip01 spine2")
	for side: String in ["l", "r"]:
		var handed := 1.0 if side == "l" else -1.0
		var hand := joint_world(rig, "bip01 %s hand" % side)
		var folded := chest + Vector3(handed * .83, -.67, 1.02)
		var guard := chest + Vector3(handed * 1.46, .13 + .24 * handed * yaw, .73)
		var raised := chest + Vector3(handed * 1.31, 1.19 - .24 * handed, .37)
		fit_arm(rig, side, hand.lerp(folded, fold).lerp(guard, wide).lerp(raised, high))
		turn_world(rig, "bip01 %s hand" % side, Vector3.BACK, handed * (.25 * wide - .32 * fold))
		turn_world(rig, "bone%s01" % side, Vector3.UP, -handed * .43 * maw)
	for index in RibGroups.size():
		var handed := -1.0 if index == 0 else 1.0
		for rib: String in RibGroups[index]:
			turn_world(rig, rib, Vector3.UP, -handed * .19 * maw)
