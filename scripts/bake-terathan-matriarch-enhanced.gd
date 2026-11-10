# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/terathan-matriarch-swamp-dragons/"
const Clips := {23: "TerathanMatriarchRearRise", 26: "TerathanMatriarchQuietTurn",
	27: "TerathanMatriarchPincerThreat", 28: "TerathanMatriarchSideAlert"}
const Lengths := {23: 1.0, 26: 1.14, 27: 1.14, 28: .72}
const Trunk := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2",
	"bip01 neck", "bip01 head", "bip01 tail1", "bip01 tail2"]
const FrontLegs := ["bone_r03", "bone31", "bone_r02", "bone16"]


func run() -> void:
	var joints := Trunk + FrontLegs
	for side: String in ["l", "r"]:
		for part: String in ["clavicle", "upperarm", "forearm", "hand"]:
			joints.append("bip01 %s %s" % [side, part])
	prepare_body(72, Clips, Lengths, joints, pose_matriarch, Destination)
	quit()


func pose_matriarch(rig: Skeleton3D, phase: float, group: int) -> void:
	var dip := 0.0
	var rise := 0.0
	var raise := 0.0
	var turn := 0.0
	match group:
		23:
			dip = .88 * (1.0 - smoothstep(.14, .54, phase))
			rise = envelope(phase, .18, .58, .76, .99)
			raise = .64 * rise
		26:
			turn = .18 * sin(TAU * phase) * sin(PI * phase)
			raise = .14 * envelope(phase, .12, .41, .58, .89)
		27:
			raise = envelope(phase, .04, .29, .54, .96)
			dip = .37 * envelope(phase, .29, .52, .68, .92)
			turn = -.29 * sin(TAU * phase)
		28:
			turn = .31 * smoothstep(.12, .78, phase)
			raise = .67 * smoothstep(.23, .89, phase)
			dip = .31 * envelope(phase, .02, .34, .51, .91)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .52 * dip - .36 * rise)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, .31 * dip - .29 * rise)
	turn_world(rig, "bip01 spine2", Vector3.UP, .42 * turn)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .21 * dip - .24 * raise)
	turn_world(rig, "bip01 head", Vector3.UP, .58 * turn)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, -.15 * dip + .27 * rise)
	turn_world(rig, "bip01 tail2", Vector3.UP, .22 * turn)
	turn_world(rig, "bone_r03", Vector3.RIGHT, -.13 * rise)
	turn_world(rig, "bone31", Vector3.RIGHT, .11 * rise)
	turn_world(rig, "bone_r02", Vector3.RIGHT, -.16 * rise)
	turn_world(rig, "bone16", Vector3.RIGHT, .14 * rise)
	var chest := joint_world(rig, "bip01 spine2")
	var head := joint_world(rig, "bip01 head")
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var hand_name := "bip01 %s hand" % side
		var hand := joint_world(rig, hand_name)
		var low := chest + Vector3(sign_x * .34, -.30, .29)
		var high := head + Vector3(sign_x * (.32 + .10 * rise), .19 + .19 * sign_x * turn, .19)
		fit_arm(rig, side, hand.lerp(low, dip).lerp(high, raise))
		turn_world(rig, hand_name, Vector3.BACK, sign_x * (.31 * raise - .18 * dip))
