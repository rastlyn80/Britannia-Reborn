# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/drake-walrus/"
const DrakeClips := {23: "DrakeFoldedTakeoff", 26: "DrakeTailScan", 27: "DrakeBroadWingbeat", 28: "DrakeSingleWingLift"}
const DrakeLengths := {23: 1.16, 26: 1.03, 27: 1.14, 28: .73}
const WalrusClips := {4: "WalrusTuskLift", 15: "WalrusThroatHitch", 25: "WalrusStillWatch",
	26: "WalrusNoseScan", 28: "WalrusHumpAlert"}
const WalrusLengths := {4: .84, 15: .56, 25: .94, 26: 1.06, 28: .68}
const DrakeJoints := ["bip01 pelvis", "bip01 spine1", "bip01 spine3", "bip01 neck", "bip01 neck1", "bip01 neck2",
	"bip01 head", "box14", "bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3",
	"bip01 l upperarm", "bip01 l forearm", "bip01 r upperarm", "bip01 r forearm",
	"box01", "box02", "box03", "box06", "box07", "box08"]
const WalrusJoints := ["bip01 pelvis", "bip01 spine", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 r upperarm", "bip01 r forearm",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]

func run() -> void:
	prepare_body(60, DrakeClips, DrakeLengths, DrakeJoints, pose_drake, Stage)
	prepare_body(221, WalrusClips, WalrusLengths, WalrusJoints, pose_walrus, Stage)
	quit()

func pose_drake(rig: Skeleton3D, phase: float, group: int) -> void:
	var fold := 0.0
	var fan := 0.0
	var left := 0.0
	var reach := 0.0
	var pitch := 0.0
	var tail := 0.0
	var curl := 0.0
	match group:
		23:
			fold = 1.0 - smoothstep(.12, .52, phase)
			fan = .88 * smoothstep(.20, .64, phase)
			reach = .48 * smoothstep(.15, .68, phase)
			pitch = .33 * fold
			curl = .35 * envelope(phase, .16, .47, .66, .94)
		26:
			fold = .51
			tail = .34 * sin(TAU * phase) * sin(PI * phase)
			curl = .33 * sin(TAU * phase)
			reach = .12 * envelope(phase, .12, .41, .68, .96)
		27:
			fold = .72 * (1.0 - envelope(phase, .03, .39, .61, .98))
			fan = .84 * envelope(phase, .06, .41, .66, .97)
			reach = .41 * envelope(phase, .10, .50, .66, .97)
			curl = .37 * sin(PI * phase)
		28:
			fold = .57 * (1.0 - smoothstep(.12, .75, phase))
			left = .74 * smoothstep(.16, .73, phase)
			reach = .21 * smoothstep(.15, .82, phase)
			tail = -.18 * sin(PI * phase)
	var paws := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.RIGHT, .34 * pitch - .11 * reach)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .55 * pitch)
	turn_world(rig, "bip01 spine3", Vector3.RIGHT, .35 * pitch - .16 * reach)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .21 * pitch - .21 * reach)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .24 * pitch - .12 * reach)
	turn_world(rig, "bip01 neck2", Vector3.RIGHT, -.17 * pitch + .21 * reach)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.41 * pitch + .18 * reach)
	turn_world(rig, "box14", Vector3.RIGHT, .24 * reach)
	turn_world(rig, "bip01 tail", Vector3.UP, .31 * tail)
	turn_world(rig, "bip01 tail1", Vector3.UP, tail)
	turn_world(rig, "bip01 tail2", Vector3.RIGHT, .71 * curl)
	turn_world(rig, "bip01 tail2", Vector3.UP, .56 * tail)
	turn_world(rig, "bip01 tail3", Vector3.RIGHT, .82 * curl)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		var limb := "bip01 " + side
		var joints := ["box06", "box07", "box08"] if side == "l" else ["box01", "box02", "box03"]
		var spread := fan + (left if side == "l" else .15 * left)
		turn_world(rig, limb + " upperarm", Vector3.RIGHT, -.52 * pitch - .23 * reach)
		turn_world(rig, limb + " forearm", Vector3.RIGHT, .69 * pitch + .18 * reach)
		turn_world(rig, joints[0], Vector3.RIGHT, -.94 * fold + .30 * spread)
		turn_world(rig, joints[0], Vector3.FORWARD, sign * .58 * spread)
		turn_world(rig, joints[1], Vector3.UP, -sign * (.63 * spread - .25 * fold))
		turn_world(rig, joints[2], Vector3.RIGHT, -.25 * fold + .36 * spread)
	anchor_hind_paws(rig, paws)

func pose_walrus(rig: Skeleton3D, phase: float, group: int) -> void:
	var lift := 0.0
	var tuck := 0.0
	var glance := 0.0
	var flipper := 0.0
	var roll := 0.0
	var breath := 0.0
	match group:
		4:
			lift = envelope(phase, .00, .25, .41, .65)
			tuck = .36 * smoothstep(.34, .72, phase)
			flipper = .34 * envelope(phase, .08, .39, .62, .98)
		15:
			lift = .72 * envelope(phase, .06, .34, .51, .90)
			tuck = .24 * envelope(phase, .23, .47, .67, .98)
		25:
			breath = sin(TAU * phase)
			glance = .055 * sin(TAU * phase)
		26:
			glance = .30 * sin(TAU * phase) * sin(PI * phase)
			tuck = .20 * envelope(phase, .10, .35, .67, .94)
			lift = .27 * envelope(phase, .03, .26, .37, .59)
		28:
			tuck = .56 * envelope(phase, .06, .44, .61, .96)
			roll = .12 * sin(PI * phase)
			flipper = .38 * envelope(phase, .16, .48, .67, .92)
	var tail := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.RIGHT, -.07 * lift + .11 * tuck)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, -.20 * lift + .25 * tuck + .027 * breath)
	turn_world(rig, "bip01 spine", Vector3.BACK, roll)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.48 * lift + .22 * tuck)
	turn_world(rig, "bip01 neck", Vector3.UP, .52 * glance)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.47 * lift - .12 * tuck)
	turn_world(rig, "bip01 head", Vector3.UP, .63 * glance)
	for side: String in ["l", "r"]:
		var sign := -1.0 if side == "l" else 1.0
		var limb := "bip01 " + side
		turn_world(rig, limb + " upperarm", Vector3.RIGHT, .21 * lift - .34 * tuck)
		turn_world(rig, limb + " upperarm", Vector3.BACK, sign * .57 * flipper)
		turn_world(rig, limb + " forearm", Vector3.RIGHT, .23 * flipper + .39 * tuck)
		turn_world(rig, limb + " thigh", Vector3.RIGHT, .16 * tuck)
		turn_world(rig, limb + " calf", Vector3.RIGHT, -.17 * tuck)
		turn_world(rig, limb + " foot", Vector3.UP, sign * .18 * flipper)
	anchor_hind_paws(rig, tail)
