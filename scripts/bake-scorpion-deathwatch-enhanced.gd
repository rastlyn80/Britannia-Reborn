# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-serpent-harpy-enhanced.gd"

const ArthropodStage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/scorpion-bimbobushi/"
const ScorpionClips := {4: "ScorpionScissorStrike", 23: "ScorpionTailRise", 25: "ScorpionQuietBrace",
	26: "ScorpionClawCheck", 27: "ScorpionRaisedPincers", 28: "ScorpionClawAlert"}
const ScorpionLengths := {4: .73, 23: 1.11, 25: 1.07, 26: 1.12, 27: .88, 28: .60}
const BeetleClips := {1: "DeathwatchTuckedWatch", 4: "DeathwatchCrossShear", 25: "DeathwatchQuietBreath",
	26: "DeathwatchPalpBrush", 27: "DeathwatchAbdomenCurl", 28: "DeathwatchForelimbAlert"}
const BeetleLengths := {1: .97, 4: .89, 25: 1.06, 26: .96, 27: 1.11, 28: .64}
const BodyJoints := [RootJoint, "bip01 spine", "bip01 spine1", "bip01 neck", "bip01 l upperarm", "bip01 r upperarm",
	"bip01 l forearm", "bip01 r forearm", "bip01 l hand", "bip01 r hand", "bip01 l thigh", "bip01 r thigh",
	"bip01 l calf", "bip01 r calf", "bip01 l foot", "bip01 r foot"]
const ScorpionJoints := ["bip01 spine2", "bip01 l finger0", "bip01 r finger0", "bip01 l toe0", "bip01 r toe0"]
const BeetleJoints := ["bip01 neck1", "bip01 head", "bip01 tail", "bip01 tail1", "bone01", "bone02", "bone03",
	"bone04", "bone06", "bone07"]

func run() -> void:
	prepare_body(48, ScorpionClips, ScorpionLengths, BodyJoints + ScorpionJoints + Tail, pose_scorpion, ArthropodStage)
	prepare_body(242, BeetleClips, BeetleLengths, BodyJoints + BeetleJoints, pose_deathwatch, ArthropodStage)
	quit()

func pose_scorpion(rig: Skeleton3D, phase: float, group: int) -> void:
	var anchor := hind_midpoint(rig)
	var neck := joint_world(rig, "bip01 neck")
	var left := joint_world(rig, "bip01 l hand")
	var right := joint_world(rig, "bip01 r hand")
	var claw := 0.0
	var strike := 0.0
	var fold := 0.0
	var curl := 0.0
	var sweep := 0.0
	match group:
		4:
			claw = envelope(phase, .01, .22, .41, .77)
			strike = envelope(phase, .17, .40, .57, .92)
			curl = -.13 * strike
		23:
			fold = 1.0 - smoothstep(.20, .57, phase)
			claw = .70 * envelope(phase, .35, .60, .77, .99)
			curl = .22 * envelope(phase, .29, .48, .56, .86)
			sweep = .30 * fold
		25:
			curl = .025 * sin(TAU * phase)
		26:
			claw = .20 * sin(PI * phase)
			sweep = .19 * sin(TAU * phase)
		27:
			claw = .80 * envelope(phase, .00, .24, .66, .99)
			curl = .16 * claw
		28:
			claw = .56 * smoothstep(.07, .82, phase)
			curl = .23 * claw
			sweep = .17 * claw
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.19 * claw + .12 * strike)
	turn_world(rig, "bip01 spine2", Vector3.UP, .18 * sweep + .12 * strike)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .20 * claw)
	for i in Tail.size():
		turn_world(rig, Tail[i], Vector3.RIGHT, curl * (.38 + .10 * i) - fold * (.66 - .09 * i))
		turn_world(rig, Tail[i], Vector3.UP, sweep * (.16 + .11 * i))
	if group != 25:
		var guard_height := .92 if group == 27 else .52
		var right_guard := neck + Vector3(-.93, guard_height, .34)
		var left_guard := neck + Vector3(.95, guard_height + .06, .31)
		fit_arm(rig, "r", right.lerp(right_guard, claw).lerp(neck + Vector3(-.15, .05, 1.04), strike))
		fit_arm(rig, "l", left.lerp(left_guard, claw).lerp(neck + Vector3(.58, -.08, .89), .57 * strike))
		turn_world(rig, "bip01 r finger0", Vector3.UP, -.32 * claw + .58 * strike)
		turn_world(rig, "bip01 l finger0", Vector3.UP, .34 * claw - .27 * strike)
	anchor_hind_paws(rig, anchor)

func pose_deathwatch(rig: Skeleton3D, phase: float, group: int) -> void:
	var anchor := hind_midpoint(rig)
	var neck := joint_world(rig, "bip01 neck")
	var left := joint_world(rig, "bip01 l hand")
	var right := joint_world(rig, "bip01 r hand")
	var bob := sin(TAU * phase)
	var crossing := 0.0
	var rear := 0.0
	var tucked := 0.0
	var brush := 0.0
	var curl := 0.0
	match group:
		1:
			tucked = .49 + .08 * bob
		4:
			rear = envelope(phase, .03, .24, .40, .88)
			crossing = envelope(phase, .13, .38, .54, .84)
			curl = .30 * crossing
		25:
			curl = .040 * bob
		26:
			brush = envelope(phase, .13, .36, .61, .95)
			curl = .09 * brush
		27:
			curl = .97 * envelope(phase, .04, .33, .70, .99)
			rear = .32 * curl
		28:
			rear = .84 * smoothstep(.06, .75, phase)
			curl = .26 * rear
	turn_world(rig, "bip01 spine", Vector3.RIGHT, -.25 * rear)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.28 * rear + .08 * tucked)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .23 * rear + .13 * brush)
	turn_world(rig, "bip01 neck1", Vector3.UP, -.21 * brush)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .14 * tucked - .18 * brush)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.66 * curl)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, -.48 * curl)
	for side: String in ["l", "r"]:
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, .20 * rear)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, -.23 * rear)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, .16 * rear)
	turn_world(rig, "bone01", Vector3.UP, .23 * brush + .17 * tucked)
	turn_world(rig, "bone04", Vector3.UP, -.19 * brush - .17 * tucked)
	turn_world(rig, "bone03", Vector3.RIGHT, .08 * bob + .19 * brush)
	turn_world(rig, "bone06", Vector3.RIGHT, -.08 * bob + .11 * brush)
	if group != 25:
		var left_ready := left.lerp(neck + Vector3(.98, .29, .46), rear).lerp(neck + Vector3(.68, -.33, -.05), tucked)
		var right_ready := right.lerp(neck + Vector3(-1.06, .31, .54), rear).lerp(neck + Vector3(-.75, -.38, -.03), tucked)
		# The forward blades pass at different heights as they cross.
		fit_arm(rig, "l", left_ready.lerp(neck + Vector3(-.16, -.16, .98), crossing).lerp(neck + Vector3(.38, -.21, .60), brush))
		fit_arm(rig, "r", right_ready.lerp(neck + Vector3(.09, -.36, .89), crossing))
	anchor_hind_paws(rig, anchor)
