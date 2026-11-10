# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/efreet-terathan-avenger/"
const Clips := {12: "AvengerCrossedPincers", 23: "AvengerUnfold", 26: "AvengerPincerWatch",
	27: "AvengerHighThreat", 28: "AvengerQuietBrace"}
const Lengths := {12: 1.04, 23: 1.05, 26: 1.04, 27: 1.15, 28: .90}
const Torso := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head"]
const Abdomen := ["bip01 tail", "bip01 tail1", "bip01 tail2"]
const FrontLegs := ["bone_r03", "bone31", "bone_r02", "bone16"]


func run() -> void:
	var joints := Torso + Abdomen + FrontLegs
	for side: String in ["l", "r"]:
		for joint: String in ["clavicle", "upperarm", "forearm", "hand"]:
			joints.append("bip01 %s %s" % [side, joint])
	prepare_body(152, Clips, Lengths, joints, pose_avenger, Destination)
	quit()


func pose_avenger(rig: Skeleton3D, phase: float, group: int) -> void:
	var fold := 0.0
	var cross := 0.0
	var raise := 0.0
	var reach := 0.0
	var gaze := 0.0
	match group:
		12:
			cross = envelope(phase, .03, .26, .37, .59)
			reach = envelope(phase, .28, .54, .72, .98)
			fold = .32 * reach
		23:
			fold = 1.0 - smoothstep(.08, .58, phase)
			raise = .66 * envelope(phase, .18, .48, .69, .97)
		26:
			gaze = .16 * sin(TAU * phase) * sin(PI * phase)
			reach = .29 * envelope(phase, .05, .28, .66, .96)
		27:
			raise = envelope(phase, .04, .24, .48, .95)
			gaze = -.30 * sin(PI * phase)
		28:
			fold = .16 * smoothstep(.13, .86, phase)
			gaze = .12 * sin(TAU * phase)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .36 * fold - .17 * raise + .14 * reach)
	turn_world(rig, "bip01 spine2", Vector3.UP, .35 * gaze)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, .22 * fold - .14 * cross)
	turn_world(rig, "bip01 head", Vector3.UP, .65 * gaze)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.20 * fold + .09 * reach)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, -.12 * fold + .14 * raise)
	turn_world(rig, "bip01 tail2", Vector3.RIGHT, .08 * raise)
	turn_world(rig, "bone_r03", Vector3.RIGHT, -.20 * reach)
	turn_world(rig, "bone31", Vector3.RIGHT, .19 * reach)
	turn_world(rig, "bone_r02", Vector3.RIGHT, -.15 * reach)
	turn_world(rig, "bone16", Vector3.RIGHT, .15 * reach)
	var chest := joint_world(rig, "bip01 spine2")
	var head := joint_world(rig, "bip01 head")
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var hand_name := "bip01 %s hand" % side
		var tip_name := "cp_grasp_%shand" % side
		var hand := joint_world(rig, hand_name)
		var folded := chest + Vector3(sign_x * .21, -.31, .19)
		var lifted := head + Vector3(sign_x * .56, .10 + .29 * sign_x * gaze, .12)
		var crossed := head + Vector3(sign_x * .17, .10, .27 + .075 * sign_x)
		var thrust := chest + Vector3(sign_x * .32, -.17, .55)
		fit_arm(rig, side, hand.lerp(folded, fold).lerp(lifted, raise).lerp(crossed, cross).lerp(thrust, reach))
		hand = joint_world(rig, hand_name)
		var tip := joint_world(rig, tip_name)
		var direction := (tip - hand).normalized()
		var threat := Vector3(sign_x * .70, .84 + .55 * sign_x * gaze, .20).normalized()
		var cross_tip := Vector3(-sign_x * .56, .86, .32).normalized()
		direction = direction.slerp(threat, raise).slerp(cross_tip, cross).slerp(Vector3(.18 * sign_x, -.32, .93).normalized(), reach)
		Arms.aim(rig, rig.find_bone(hand_name), rig.find_bone(tip_name), rig.to_local(hand + direction))
		rig.force_update_all_bone_transforms()
