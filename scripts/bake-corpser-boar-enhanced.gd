# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/corpser-boar/"
const CorpserClips := {4: "CorpserTripleSweep", 15: "CorpserClosedCanopy", 25: "CorpserQuietBloom",
	26: "CorpserClosePetals", 27: "CorpserSplay", 28: "CorpserRaisedTendrils"}
const CorpserLengths := {4: .72, 15: .60, 25: 1.0, 26: 1.10, 27: .90, 28: .67}
const CorpserJoints := ["bip01 pelvis", "bip01 spine", "bip01 neck", "bip01 head",
	"bip01 ponytail1", "bip01 ponytail11", "bip01 ponytail12", "bip01 ponytail13",
	"bip01 ponytail2", "bip01 ponytail21", "bip01 ponytail22", "bip01 ponytail23",
	"bip01 r clavicle", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l clavicle", "bip01 l upperarm", "bip01 l forearm", "bip01 l hand"]
const BoarClips := {4: "BoarTuskFlick", 15: "BoarSnoutRecoil", 25: "BoarQuietStand",
	26: "BoarScentCheck", 27: "BoarLowGuard", 28: "BoarEarAlert"}
const BoarLengths := {4: .55, 15: .60, 25: 1.0, 26: .90, 27: .80, 28: .70}

func run() -> void:
	prepare_body(8, CorpserClips, CorpserLengths, CorpserJoints, pose_corpser, Stage)
	prepare_body(290, BoarClips, BoarLengths, CommonJoints + ["bip01 neck1"], pose_boar, Stage)
	quit()

func pose_corpser(rig: Skeleton3D, phase: float, group: int) -> void:
	var close := 0.0
	var fold := 0.0
	var sweep := 0.0
	var raise := 0.0
	var spread := 0.0
	match group:
		4:
			sweep = envelope(phase, .09, .40, .64, .96)
			close = .65 * sweep
			spread = .34 * (1.0 - sweep)
		15:
			fold = envelope(phase, .03, .23, .65, .96)
			close = .58 * fold
		25:
			raise = .04 * sin(TAU * phase)
		26:
			close = .92 * envelope(phase, 0.0, .19, .61, .94)
			raise = .08 * sin(TAU * phase)
		27:
			fold = .78 * envelope(phase, .11, .33, .35, .47)
			spread = .72 * envelope(phase, .35, .52, .72, .99)
			close = .32 * fold - .32 * spread
		28:
			raise = .58 * smoothstep(.04, .59, phase)
			spread = .28 * raise
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .12 * sweep - .11 * raise)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .22 * close - .12 * spread)
	turn_world(rig, "bip01 l clavicle", Vector3.BACK, -.50 * close + .21 * spread)
	turn_world(rig, "bip01 l upperarm", Vector3.BACK, -.25 * close)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, .36 * close)
	for index in 2:
		var label := "bip01 ponytail%d" % (index + 1)
		var side := -1.0 if index == 0 else 1.0
		var forward := (joint_world(rig, label + "1") - joint_world(rig, label)).slide(Vector3.UP).normalized()
		var hinge := forward.cross(Vector3.UP).normalized()
		turn_world(rig, label, hinge, .61 * fold + .20 * raise - .24 * spread)
		turn_world(rig, label + "1", hinge, .42 * fold - .46 * sweep)
		var lower_sweep := .10 if index == 1 else -.23
		turn_world(rig, label + "2", hinge, .73 * fold + .37 * raise + lower_sweep * sweep)
		turn_world(rig, label + "3", hinge, -.29 * fold - .30 * spread + .16 * sweep)
		turn_world(rig, label, Vector3.UP, side * (.52 * sweep - .35 * spread))
		turn_world(rig, label + "1", Vector3.UP, side * (.38 * sweep + .22 * fold))
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -.43 * fold - .26 * raise - .15 * sweep)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -.72 * fold - .28 * raise - .10 * sweep)
	turn_world(rig, "bip01 r hand", Vector3.RIGHT, .39 * fold - .24 * spread)

func pose_boar(rig: Skeleton3D, phase: float, group: int) -> void:
	var dip := 0.0
	var yaw := 0.0
	var brace := 0.0
	var rise := 0.0
	var ears := 0.0
	match group:
		4:
			var toss := envelope(phase, .06, .26, .35, .61)
			var settle := envelope(phase, .36, .57, .80, .97)
			dip = .38 * settle - .28 * toss
			rise = .57 * toss
			brace = .39 * settle
		15:
			dip = .31 * envelope(phase, .05, .43, .56, .90)
			brace = .25 * sin(PI * phase)
		25:
			dip = .022 * sin(TAU * phase)
		26:
			dip = .26 * envelope(phase, .16, .46, .61, .92)
			yaw = .23 * sin(TAU * phase) * sin(PI * phase)
		27:
			brace = .35 + .13 * sin(PI * phase)
			dip = .15 + .11 * sin(TAU * phase)
		28:
			dip = .20 * envelope(phase, .03, .31, .60, .94)
			ears = .38 * sin(PI * phase)
	var anchor := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.RIGHT, .06 * brace - .30 * rise)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .26 * brace - .29 * rise)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .28 * dip)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .48 * dip)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .52 * dip - .12 * rise)
	turn_world(rig, "bip01 head", Vector3.UP, yaw)
	turn_world(rig, "bip01 ponytail1", Vector3.BACK, ears)
	turn_world(rig, "bip01 ponytail2", Vector3.BACK, -ears)
	turn_world(rig, "bip01 tail", Vector3.UP, .35 * sin(TAU * phase) * (.11 + brace))
	for side: String in ["l", "r"]:
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.35 * brace + .47 * rise)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, .45 * brace + .40 * rise)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.27 * brace + .27 * rise)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .24 * brace - .16 * rise)
	anchor_hind_paws(rig, anchor)
