# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/rotting-corpse-bog-thing/"
const Clips := {11: "RottingCorpseCradle", 15: "RottingCorpseSkullShield",
	23: "RottingCorpseUncurl", 26: "RottingCorpseStrayReach",
	27: "RottingCorpseRaggedFlail", 28: "RottingCorpseThreatStep"}
const Lengths := {11: 1.02, 15: .72, 23: 1.07, 26: 1.04, 27: 1.05, 28: .94}
const Torso := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 neck1", "bip01 head"]


func run() -> void:
	var joints := Torso.duplicate()
	for side: String in ["l", "r"]:
		for joint: String in ["upperarm", "forearm", "hand", "thigh", "calf", "foot"]:
			joints.append("bip01 %s %s" % [side, joint])
	prepare_body(155, Clips, Lengths, joints, pose_rotting_corpse, Destination)
	quit()


func pose_rotting_corpse(rig: Skeleton3D, phase: float, group: int) -> void:
	var fold := 0.0
	var ward := 0.0
	var loose := 0.0
	var reach := 0.0
	var shift := 0.0
	match group:
		11:
			fold = .82 * envelope(phase, .04, .32, .68, .97)
			ward = .42 * (1.0 - fold)
		15:
			ward = 1.0 - .82 * smoothstep(.49, .95, phase)
			fold = .18 * envelope(phase, .05, .22, .68, .97)
		23:
			fold = 1.0 - smoothstep(.12, .78, phase)
			shift = .15 * sin(PI * phase)
		26:
			reach = .84 * envelope(phase, .09, .46, .67, .96)
			fold = .14 * reach
		27:
			loose = .83 + .17 * sin(TAU * phase)
			ward = .17 * sin(PI * phase)
			shift = .16 * sin(TAU * phase)
		28:
			loose = .77 * smoothstep(.16, .85, phase)
			fold = .21 * (1.0 - loose)
			shift = -.12 * sin(PI * phase)
	var feet: Array[Transform3D] = []
	for side: String in ["l", "r"]:
		var foot := rig.get_bone_global_pose(rig.find_bone("bip01 %s foot" % side))
		var step := envelope(phase, .23, .46, .66, .90)
		if side == "l" and group in [11, 27, 28]:
			foot.origin += rig.global_basis.inverse() * Vector3(.10 * step, .13 * step, -.14 * step)
		feet.append(foot)
	var pelvis := rig.find_bone(RootJoint)
	var base := rig.get_bone_global_pose(pelvis)
	base.origin += rig.global_basis.inverse() * Vector3(shift, -.67 * fold - .12 * loose, -.19 * fold)
	rig.set_bone_global_pose(pelvis, base)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .24 * fold + .06 * reach)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .48 * fold - .13 * ward)
	turn_world(rig, "bip01 spine2", Vector3.UP, .53 * shift + .11 * reach)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.34 * ward + .18 * fold)
	turn_world(rig, "bip01 head", Vector3.UP, -.46 * shift - .23 * reach)
	fit_foot(rig, "l", feet[0])
	fit_foot(rig, "r", feet[1])
	var chest := joint_world(rig, "bip01 spine2")
	var head := joint_world(rig, "bip01 head")
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var hand_name := "bip01 %s hand" % side
		var hand := joint_world(rig, hand_name)
		var tucked := chest + Vector3(sign_x * .27, -.38, .39)
		var shielding := head + Vector3(sign_x * .31, -.06, .42)
		var flailing := chest + Vector3(sign_x * .73, .22 + .19 * sign_x * sin(TAU * phase), .33)
		var reaching := chest + Vector3(sign_x * .33, -.09, .82)
		hand = hand.lerp(tucked, fold).lerp(shielding, ward).lerp(flailing, loose)
		fit_arm(rig, side, hand.lerp(reaching, reach if side == "r" else .22 * reach))
		turn_world(rig, hand_name, Vector3.RIGHT, .27 * ward - .32 * reach + .11 * loose)
