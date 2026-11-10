# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const WolfStage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/tsuki-wolf-ophidian/"
const WolfClips := {12: "TsukiTripleRake", 23: "TsukiUnfold", 26: "TsukiThreeWayWatch",
	27: "TsukiHighGuard", 28: "TsukiPackAlert"}
const WolfLengths := {12: .97, 23: 1.20, 26: 1.06, 27: 1.03, 28: .82}
const WolfJoints := ["bip01", "bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 neck", "bip01 head",
	"jaw_bone", "l_neck_bone", "r_neck_bone", "l_head_bone", "r_head_bone", "l_jaw_bone", "r_jaw_bone",
	"bip01 l clavicle", "bip01 r clavicle", "bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm",
	"bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf", "bip01 l foot", "bip01 r foot"]

func run() -> void:
	prepare_body(250, WolfClips, WolfLengths, WolfJoints, pose_wolf, WolfStage)
	quit()

func pose_wolf(rig: Skeleton3D, phase: float, group: int) -> void:
	var crouch := 0.0
	var rake := 0.0
	var wind := 0.0
	var guard := 0.0
	var threat := 0.0
	var scan := 0.0
	match group:
		12:
			wind = 1.0 - smoothstep(.13, .45, phase)
			rake = envelope(phase, .24, .49, .67, .98)
			crouch = .41 * rake
			threat = .72 * rake
		23:
			crouch = 1.0 - smoothstep(.11, .70, phase)
			guard = .62 * envelope(phase, .27, .55, .76, 1.0)
			threat = .42 * smoothstep(.28, .74, phase)
		26:
			scan = .27 * sin(TAU * phase) * sin(PI * phase)
			crouch = .07 * sin(PI * phase)
			guard = .13 * envelope(phase, .08, .32, .59, .96)
		27:
			guard = .78 + .22 * envelope(phase, .04, .35, .59, .91)
			crouch = .20 * envelope(phase, .28, .61, .75, .98)
			scan = -.17 * sin(PI * phase)
		28:
			threat = .69 * smoothstep(.11, .72, phase)
			guard = .35 * envelope(phase, .07, .38, .69, 1.0)
			crouch = .33 * threat
	var anchor := hind_midpoint(rig)
	turn_world(rig, "bip01", Vector3.RIGHT, .67 * crouch - .13 * wind)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .36 * crouch + .17 * rake)
	turn_world(rig, "bip01 spine1", Vector3.UP, scan - .23 * rake)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.43 * crouch + .17 * rake)
	turn_world(rig, "bip01 head", Vector3.UP, -.39 * scan)
	turn_world(rig, "jaw_bone", Vector3.RIGHT, .44 * threat)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		var limb := "bip01 " + side
		var raised := guard if side == "r" else guard * .29
		var strike := rake if side == "r" else .36 * rake
		var jaw_phase := sin(PI * clampf(phase + .10 * sign, 0.0, 1.0))
		turn_world(rig, side + "_neck_bone", Vector3.UP, sign * (.32 * threat + .23 * jaw_phase) + .74 * scan)
		turn_world(rig, side + "_neck_bone", Vector3.RIGHT, -.30 * crouch + sign * .11 * jaw_phase)
		turn_world(rig, side + "_head_bone", Vector3.RIGHT, sign * .16 * threat)
		turn_world(rig, side + "_jaw_bone", Vector3.RIGHT, .42 * threat * jaw_phase)
		turn_world(rig, limb + " clavicle", Vector3.UP, .13 * strike)
		turn_world(rig, limb + " upperarm", Vector3.RIGHT, -.95 * wind - 1.25 * raised + .52 * strike - .72 * crouch)
		turn_world(rig, limb + " upperarm", Vector3.BACK, sign * (.51 * raised + .22 * strike))
		turn_world(rig, limb + " forearm", Vector3.RIGHT, -.44 * wind - .68 * raised + .61 * strike - .56 * crouch)
		turn_world(rig, limb + " thigh", Vector3.RIGHT, -1.0 * crouch)
		turn_world(rig, limb + " calf", Vector3.RIGHT, .79 * crouch)
		turn_world(rig, limb + " foot", Vector3.RIGHT, -.46 * crouch)
	anchor_hind_paws(rig, anchor)
