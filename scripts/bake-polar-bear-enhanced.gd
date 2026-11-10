# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const PolarStage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/polar-bear/"
const PolarClips := {4: "PolarStandingRake", 15: "PolarUprightThreat", 23: "PolarMuzzleUpAndRise",
	25: "PolarStillWatch", 26: "PolarWindScent", 27: "PolarPawHighGuard", 28: "PolarCrouchToRear"}
const PolarLengths := {4: .81, 15: .54, 23: 1.15, 25: .93, 26: 1.08, 27: .81, 28: .89}

func run() -> void:
	prepare_body(213, PolarClips, PolarLengths, CommonJoints + ["bip01 spine2", "box01"], pose_polar, PolarStage)
	quit()

func pose_polar(rig: Skeleton3D, phase: float, group: int) -> void:
	var rear := 0.0
	var crouch := 0.0
	var scent := 0.0
	var threat := 0.0
	var rake := 0.0
	var paw := 0.0
	var yaw := 0.0
	var breath := 0.0
	match group:
		4:
			rear = .91 - .14 * envelope(phase, .27, .48, .64, .97)
			rake = envelope(phase, .13, .45, .65, .98)
			paw = .44 * (1.0 - smoothstep(.11, .32, phase))
			threat = .43 + .35 * rake
		15:
			rear = .84 + .033 * sin(PI * phase)
			threat = .44 + .37 * envelope(phase, .03, .43, .53, .98)
			scent = .18 * sin(PI * phase)
		23:
			crouch = 1.0 - smoothstep(.24, .94, phase)
			scent = .38 * envelope(phase, .12, .51, .70, 1.0)
			threat = .19 * envelope(phase, .31, .57, .68, .92)
		25:
			breath = sin(TAU * phase)
			yaw = .07 * sin(PI * phase)
		26:
			crouch = .29 * envelope(phase, .03, .32, .48, .73)
			scent = .53 * envelope(phase, .34, .67, .78, .99)
			yaw = .18 * sin(PI * phase)
		27:
			rear = .95 + .04 * sin(PI * phase)
			threat = .58 + .40 * envelope(phase, .16, .48, .56, .96)
			paw = .84 + .16 * sin(PI * phase)
			scent = .13 * sin(PI * phase)
		28:
			crouch = .63 * envelope(phase, .03, .43, .55, .77)
			rear = .85 * smoothstep(.58, .98, phase)
			threat = .41 * smoothstep(.65, .96, phase)
	var anchor := hind_midpoint(rig)
	var prone := group == 23
	turn_world(rig, RootJoint, Vector3.RIGHT, -1.24 * rear + (.09 if prone else .28) * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .13 * rear + (.14 if prone else .35) * crouch + .23 * rake)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, .036 * breath)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .37 * rear + .30 * crouch - .53 * scent)
	turn_world(rig, "bip01 neck", Vector3.UP, .46 * yaw)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .34 * rear - .19 * crouch - .34 * scent + .22 * rake)
	turn_world(rig, "bip01 head", Vector3.UP, .64 * yaw)
	turn_world(rig, "box01", Vector3.RIGHT, .26 * threat)
	for side: String in ["l", "r"]:
		var limb := "bip01 " + side
		var sign := 1.0 if side == "l" else -1.0
		var strike := rake if side == "r" else .26 * rake
		var high_paw := paw if side == "l" else 0.0
		turn_world(rig, limb + " thigh", Vector3.RIGHT, .94 * rear - (.63 if prone else .41) * crouch)
		turn_world(rig, limb + " calf", Vector3.RIGHT, .18 * rear + (.79 if prone else .51) * crouch)
		turn_world(rig, limb + " foot", Vector3.RIGHT, .18 * rear - .24 * crouch)
		turn_world(rig, limb + " upperarm", Vector3.RIGHT, .28 * rear - .60 * crouch - .57 * high_paw + .69 * strike)
		turn_world(rig, limb + " upperarm", Vector3.BACK, sign * (.25 * rear + .57 * threat + 1.25 * high_paw))
		turn_world(rig, limb + " forearm", Vector3.RIGHT, -.64 * rear + .86 * crouch - .41 * high_paw + .51 * strike)
		turn_world(rig, limb + " hand", Vector3.RIGHT, .17 * rear - .41 * crouch + .25 * strike)
	anchor_hind_paws(rig, anchor)
