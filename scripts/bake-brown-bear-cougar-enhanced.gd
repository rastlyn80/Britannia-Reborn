# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const BrownCougarFolder := "res://../work/creatures/native-form-audit/enhanced-source-gaps/brown-bear-cougar/"
const BrownBearClips := {4: "BrownBearHighSwipe", 15: "BrownBearUprightWarning", 23: "BrownBearWakeAndRise",
	25: "BrownBearQuietStand", 26: "BrownBearScentTurn", 27: "BrownBearRaisedGuard", 28: "BrownBearRearAlert"}
const CougarClips := {4: "CougarHighPawStrike", 15: "CougarLowFeint", 23: "CougarUncoilAndStretch",
	25: "CougarQuietStand", 26: "CougarScentDip", 27: "CougarTailFlick", 28: "CougarLoweredAlert"}
const CougarLengths := {4: .80, 15: .70, 23: .90, 25: .70, 26: 1.10, 27: .80, 28: .60}
const CougarJoints := ["bip01 spine2", "bip01 spine3", "bip01 tail1", "bip01 tail2", "bip01 tail3",
	"bip01 l clavicle", "bip01 r clavicle", "bip01 l finger0", "bip01 r finger0"]

func run() -> void:
	prepare_body(167, BrownBearClips, BearLengths, CommonJoints + ["bip01 spine2", "box01",
		"bip01 l horselink", "bip01 r horselink"], pose_brown_bear, BrownCougarFolder)
	var feline_joints: Array = CommonJoints.filter(func(joint: String): return not joint.begins_with("bip01 ponytail"))
	prepare_body(63, CougarClips, CougarLengths, feline_joints + CougarJoints, pose_cougar, BrownCougarFolder)
	quit()

func pose_brown_bear(rig: Skeleton3D, phase: float, group: int) -> void:
	if group != 23:
		pose_bear(rig, phase, group)
		return
	var anchor := hind_midpoint(rig)
	var rest := 1.0 - smoothstep(.32, .92, phase)
	var waking := envelope(phase, .28, .60, .74, 1.0)
	turn_world(rig, RootJoint, Vector3.RIGHT, .11 * rest)
	turn_world(rig, RootJoint, Vector3.BACK, -.12 * rest)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .13 * rest)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .17 * rest - .25 * waking)
	turn_world(rig, "bip01 head", Vector3.UP, .20 * rest)
	turn_world(rig, "box01", Vector3.RIGHT, .14 * waking)
	for side: String in ["l", "r"]:
		var outward := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.78 * rest)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.BACK, outward * .28 * rest)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, 1.47 * rest)
		turn_world(rig, "bip01 %s horselink" % side, Vector3.RIGHT, .61 * rest)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -1.66 * rest)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -1.85 * rest)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, outward * .23 * rest)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, .46 * rest)
		turn_world(rig, "bip01 %s hand" % side, Vector3.RIGHT, .78 * rest)
	anchor_hind_paws(rig, anchor)

func pose_cougar(rig: Skeleton3D, phase: float, group: int) -> void:
	var crouch := 0.0
	var rear := 0.0
	var strike := 0.0
	var stretch := 0.0
	var head_dip := 0.0
	var head_turn := 0.0
	var tail_curl := 0.0
	var tail_sweep := 0.0
	match group:
		4:
			rear = envelope(phase, .17, .37, .42, .72)
			strike = envelope(phase, .16, .36, .42, .63)
			crouch = .77 * (1.0 - rear)
			tail_curl = .42 * rear
		15:
			crouch = .70 - .38 * envelope(phase, .39, .78, .83, .99)
			stretch = .51 * envelope(phase, .34, .63, .77, .98)
			tail_curl = .58 * (1.0 - smoothstep(.27, .88, phase))
		23:
			var rise := smoothstep(.17, .69, phase)
			crouch = .84 - .52 * rise
			stretch = .97 - .63 * smoothstep(.57, .97, phase)
			tail_curl = 1.4 * (1.0 - rise)
			tail_sweep = 1.15 * (1.0 - rise) - .26 * sin(PI * phase)
		25:
			head_dip = .036 * sin(TAU * phase)
		26:
			head_dip = .29 * envelope(phase, .00, .31, .65, .97)
			head_turn = .26 * sin(TAU * phase) * sin(PI * phase)
			tail_sweep = .23 * sin(TAU * phase)
		27:
			var lift := envelope(phase, .02, .37, .70, .99)
			crouch = .50 - .32 * lift
			head_dip = -.23 * lift
			tail_curl = .32 * lift
			tail_sweep = .67 * sin(TAU * phase) * sin(PI * phase)
		28:
			crouch = .70 * smoothstep(.04, .82, phase)
			head_dip = .19 * smoothstep(.11, .82, phase)
			tail_curl = .20 * sin(PI * phase)
	var anchor := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.RIGHT, -.55 * rear + .16 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.35 * rear + .17 * crouch)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, -.21 * rear + .14 * crouch)
	turn_world(rig, "bip01 spine3", Vector3.RIGHT, -.11 * rear + .08 * stretch)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .19 * rear + .61 * head_dip - .20 * crouch)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .11 * rear + .51 * head_dip - .19 * crouch)
	turn_world(rig, "bip01 head", Vector3.UP, head_turn)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.29 * rear + .26 * tail_curl)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, -.32 * tail_curl)
	turn_world(rig, "bip01 tail1", Vector3.UP, tail_sweep)
	turn_world(rig, "bip01 tail2", Vector3.UP, .82 * tail_sweep)
	turn_world(rig, "bip01 tail3", Vector3.UP, .71 * tail_sweep)
	for side: String in ["l", "r"]:
		var reach := strike * (1.0 if side == "r" else .74)
		var long_reach := stretch if side == "l" else stretch * (.62 + .23 * smoothstep(.12, .65, phase))
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, .36 * rear - .19 * crouch)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, -.11 * rear + .23 * crouch)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, .21 * rear - .14 * crouch)
		turn_world(rig, "bip01 %s clavicle" % side, Vector3.RIGHT, -.31 * long_reach - .22 * reach)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.61 * reach - .78 * long_reach - .62 * crouch)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, .38 * reach - .34 * long_reach + .68 * crouch)
		turn_world(rig, "bip01 %s hand" % side, Vector3.RIGHT, .21 * reach + .29 * long_reach - .31 * crouch)
		turn_world(rig, "bip01 %s finger0" % side, Vector3.RIGHT, .20 * reach - .13 * stretch)
	anchor_hind_paws(rig, anchor)
