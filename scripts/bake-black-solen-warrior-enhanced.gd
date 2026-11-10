# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/solen-warriors/"
const Clips := {
	11: "BlackSolenWarriorLowSweep", 12: "BlackSolenWarriorRaisedClaws",
	15: "BlackSolenWarriorTuck", 23: "BlackSolenWarriorUnfold",
	25: "BlackSolenWarriorQuietIdle", 26: "BlackSolenWarriorAntennaCheck",
	27: "BlackSolenWarriorHighFeint", 28: "BlackSolenWarriorLowerGuard",
}
const Lengths := {11: .86, 12: 1.08, 15: .72, 23: 1.08, 25: 1.10, 26: 1.0, 27: .97, 28: .84}
const Legs := ["lf", "lm", "lr", "rf", "rm", "rr"]
const Upper := ["bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head", "bip01 tail1",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"antenna l", "antenna r"]


func run() -> void:
	var joints := Upper.duplicate()
	for leg: String in Legs:
		joints.append("legbone %s1" % leg)
		joints.append("legbone %s2" % leg)
	prepare_body(806, Clips, Lengths, joints, pose_warrior, Destination)
	quit()


func pose_warrior(rig: Skeleton3D, phase: float, group: int) -> void:
	var fold := 0.0
	var look := 0.0
	var left_high := 0.0
	var right_high := 0.0
	var left_low := 0.0
	var right_low := 0.0
	var brace := 0.0
	match group:
		11:
			left_low = envelope(phase, .11, .52, .69, .95)
			right_low = .50 * left_low
			fold = .41 * left_low
			look = -.16 * left_low
		12:
			left_high = envelope(phase, .09, .36, .57, .93)
			right_high = envelope(phase, .12, .42, .63, .98)
			brace = .45 * maxf(left_high, right_high)
		15:
			fold = .49 * envelope(phase, .08, .40, .61, .96)
			left_low = .62 * fold
			right_low = .80 * fold
			look = .20 * fold
		23:
			fold = 1.0 - smoothstep(.16, .81, phase)
			left_low = .74 * fold
			right_low = .83 * fold
			look = -.27 * fold
			brace = .21 * fold
		25:
			fold = .025 * (1.0 - cos(TAU * phase))
			look = .034 * sin(TAU * phase)
		26:
			look = .53 * envelope(phase, .07, .35, .61, .92)
			right_high = .31 * look
			brace = .17 * look
		27:
			right_high = envelope(phase, .12, .49, .61, .96)
			left_low = .37 * right_high
			look = -.22 * right_high
			brace = .32 * right_high
		28:
			fold = .39 * smoothstep(.15, .76, phase)
			right_low = .44 * fold
			left_low = .53 * fold
			look = .15 * fold
			brace = .26 * fold

	var pelvis := rig.find_bone(RootJoint)
	var hips := rig.get_bone_global_pose(pelvis)
	hips.origin += rig.global_basis.inverse() * Vector3(.045 * look, -.22 * fold, -.10 * brace)
	rig.set_bone_global_pose(pelvis, hips)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .29 * fold - .16 * brace)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .49 * fold - .24 * brace)
	turn_world(rig, "bip01 spine2", Vector3.UP, .34 * look)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.28 * fold + .17 * brace)
	turn_world(rig, "bip01 head", Vector3.UP, .54 * look)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, -.21 * fold + .13 * brace)
	var chest := joint_world(rig, "bip01 spine2")
	for side: String in ["l", "r"]:
		var handed := 1.0 if side == "l" else -1.0
		var low := left_low if side == "l" else right_low
		var high := left_high if side == "l" else right_high
		var hand := joint_world(rig, "bip01 %s hand" % side)
		var lower := chest + Vector3(handed * (.42 + .31 * low), -.67, .68 + .15 * low)
		var upper := chest + Vector3(handed * (.70 + .19 * high), .70, .63)
		fit_arm(rig, side, hand.lerp(lower, low).lerp(upper, high))
		turn_world(rig, "bip01 %s hand" % side, Vector3.BACK, handed * (.34 * high - .27 * low))
		turn_world(rig, "antenna " + side, Vector3.UP, .65 * look + handed * .15 * high)
	for leg: String in Legs:
		var side := 1.0 if leg.begins_with("l") else -1.0
		var spread := .13 * fold + .09 * brace
		turn_world(rig, "legbone %s1" % leg, Vector3.BACK, side * spread)
		turn_world(rig, "legbone %s2" % leg, Vector3.BACK, -side * spread * .87)
