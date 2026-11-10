# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-serpent-harpy-enhanced.gd"

const UndeadStage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/zombie-wraith/"
const ZombieClips := {4: "ZombieLurchSwipe", 23: "ZombieGraveRise", 25: "ZombieQuietSway",
	26: "ZombieSlumpedWatch", 27: "ZombieTwistedGuard", 28: "ZombieArmsUp"}
const ZombieLengths := {4: .82, 23: 1.35, 25: 1.18, 26: .92, 27: .78, 28: .70}
const WraithClips := {12: "WraithSurge", 26: "WraithVeilInspect", 27: "WraithVeilDive", 28: "WraithWindborneReach"}
const WraithLengths := {12: .80, 26: 1.12, 27: 1.04, 28: .56}
const UndeadTorso := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 r clavicle", "bip01 r upperarm", "bip01 r forearm", "bip01 l clavicle", "bip01 l upperarm", "bip01 l forearm"]
const ZombieFeet := ["bip01 r thigh", "bip01 r calf", "bip01 r foot", "bip01 l thigh", "bip01 l calf", "bip01 l foot"]
const WraithCloth := ["bip01 ponytail1", "bip01 ponytail11", "bip01 ponytail12", "bip01 ponytail2",
	"bip01 ponytail21", "bip01 ponytail22", "bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3"]

func run() -> void:
	prepare_body(3, ZombieClips, ZombieLengths, UndeadTorso + ZombieFeet, pose_zombie, UndeadStage, fit_grave_depth)
	prepare_body(26, WraithClips, WraithLengths, UndeadTorso + WraithCloth, pose_wraith, UndeadStage, fit_wraith_hover)
	quit()

func pose_zombie(rig: Skeleton3D, phase: float, group: int) -> void:
	var anchor := hind_midpoint(rig)
	var hip := joint_world(rig, RootJoint)
	var right := joint_world(rig, "bip01 r hand")
	var left := joint_world(rig, "bip01 l hand")
	var reach := 0.0
	var wind := 0.0
	var hunch := 0.0
	var twist := 0.0
	var head := 0.0
	match group:
		4:
			wind = envelope(phase, .01, .17, .25, .43)
			reach = envelope(phase, .22, .47, .66, .98)
			twist = .61 * wind - .40 * reach
			hunch = .65 * reach
		23:
			reach = envelope(phase, .02, .38, .53, .93)
			wind = .85 * (1.0 - smoothstep(.22, .54, phase))
			hunch = .88 * envelope(phase, .20, .50, .63, .95)
			twist = -.34 * reach
		25:
			head = .11 * sin(TAU * phase)
			hunch = .045 * sin(TAU * phase)
		26:
			head = .24 * sin(PI * phase)
			hunch = .25 * sin(PI * phase)
		27:
			wind = .45 * envelope(phase, .01, .22, .73, 1.0)
			reach = .51 * sin(PI * phase)
			hunch = .73 * reach
			twist = .51 * reach
		28:
			reach = .62 * smoothstep(.07, .86, phase)
			hunch = .48 * reach
			twist = -.35 * reach
	turn_world(rig, RootJoint, Vector3.FORWARD, -.27 * twist)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .38 * hunch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .31 * hunch - .15 * wind)
	turn_world(rig, "bip01 spine2", Vector3.UP, twist)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .40 * head - .19 * hunch)
	turn_world(rig, "bip01 head", Vector3.UP, head - .38 * twist)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.65 * hunch + .22 * twist * sign_x)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .98 * hunch)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.42 * hunch)
	var high := Vector3(-.40, .98, .21) if group == 23 else Vector3(-.52, .82, -.05)
	var forward := Vector3(-.30, .18, .69) if group == 23 else Vector3(-.05, .34, .68)
	fit_arm(rig, "r", right.lerp(hip + high, wind).lerp(hip + forward, reach))
	fit_arm(rig, "l", left.lerp(hip + Vector3(.55, .23, .48), .87 * reach))
	anchor_hind_paws(rig, anchor)

func fit_grave_depth(clip: Animation, rig: Skeleton3D, group: int) -> void:
	if group == 23:
		offset_root(clip, rig, func(phase: float): return -2.075 * (1.0 - smoothstep(.02, .94, phase)))

func pose_wraith(rig: Skeleton3D, phase: float, group: int) -> void:
	var hip := joint_world(rig, RootJoint)
	var right := joint_world(rig, "bip01 r hand")
	var left := joint_world(rig, "bip01 l hand")
	var dive := 0.0
	var reach := 0.0
	var inspect := 0.0
	var bank := 0.0
	match group:
		12:
			dive = envelope(phase, .04, .34, .58, .90)
			reach = envelope(phase, .17, .43, .68, .97)
			bank = -.24 * sin(TAU * phase)
		26:
			inspect = envelope(phase, .06, .31, .79, .99)
			bank = .15 * inspect
		27:
			dive = .94 * envelope(phase, .02, .32, .81, .99)
			reach = .75 * dive
			bank = .33 * sin(PI * phase)
		28:
			reach = .79 * smoothstep(.08, .61, phase)
			dive = .58 * reach
			bank = -.31 * reach
	turn_world(rig, RootJoint, Vector3.RIGHT, .78 * dive)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .47 * dive)
	turn_world(rig, "bip01 spine1", Vector3.BACK, bank)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.62 * dive + .23 * inspect)
	turn_world(rig, "bip01 head", Vector3.UP, -.42 * inspect - .16 * bank)
	for chain: String in ["ponytail1", "ponytail2"]:
		turn_world(rig, "bip01 " + chain, Vector3.RIGHT, -.88 * dive)
		turn_world(rig, "bip01 " + chain + "1", Vector3.RIGHT, -.30 * dive)
		turn_world(rig, "bip01 " + chain + "2", Vector3.BACK, bank)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.60 * dive)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, -.36 * dive)
	turn_world(rig, "bip01 tail2", Vector3.BACK, -.39 * bank)
	fit_arm(rig, "r", right.lerp(hip + Vector3(-.26, .81, .47), inspect)
		.lerp(hip + Vector3(-.60, .22, .62), reach))
	fit_arm(rig, "l", left.lerp(hip + Vector3(.43, .31, .67), reach))

func fit_wraith_hover(clip: Animation, rig: Skeleton3D, group: int) -> void:
	var height := .37 if group in [12, 27] else .22
	offset_root(clip, rig, func(phase: float): return .14 + height * sin(PI * phase))
