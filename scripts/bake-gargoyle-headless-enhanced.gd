# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-serpent-harpy-enhanced.gd"

const GargoyleHeadlessStage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/gargoyle-headless/"
const GargoyleClips := {23: "GargoyleWingRise", 26: "GargoyleWingWatch", 27: "GargoyleWingFeint", 28: "GargoyleWingAlert"}
const GargoyleLengths := {23: 1.24, 26: 1.18, 27: 1.0, 28: .65}
const HeadlessClips := {23: "HeadlessGatherRise", 28: "HeadlessCrookedAlert"}
const HeadlessLengths := {23: 1.12, 28: .65}
const Limbs := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm",
	"bip01 l hand", "bip01 r hand", "bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf",
	"bip01 l foot", "bip01 r foot"]
const Membrane := ["mainwing1", "mainwing2", "wing1", "wing2", "wing3", "wing4"]

func run() -> void:
	var wings := ["bip01 head", "wing_connector"]
	for side: String in ["l", "r"]:
		for joint: String in Membrane:
			wings.append("gargoyle %s %s" % [side, joint])
	prepare_body(4, GargoyleClips, GargoyleLengths, Limbs + wings, pose_gargoyle, GargoyleHeadlessStage, place_gargoyle)
	prepare_body(31, HeadlessClips, HeadlessLengths, Limbs + ["bip01 spine3"], pose_headless, GargoyleHeadlessStage)
	quit()

func pose_gargoyle(rig: Skeleton3D, phase: float, group: int) -> void:
	var anchor := hind_midpoint(rig)
	var folded := 0.0
	var wing_open := .34
	var bank := 0.0
	var crouch := 0.0
	var warning := 0.0
	var look := 0.0
	match group:
		23:
			folded = 1.0 - smoothstep(.05, .53, phase)
			wing_open = .28 * (1.0 - folded) + .78 * envelope(phase, .24, .52, .72, .99)
			bank = .38 * envelope(phase, .32, .58, .76, .97)
			crouch = folded
			warning = .34 * wing_open
		27:
			wing_open = .47 + .35 * envelope(phase, .14, .58, .74, .99)
			bank = -.47 + .58 * sin(PI * phase)
			crouch = .34 * sin(PI * phase)
			look = .29 * sin(PI * phase)
		28:
			warning = smoothstep(.03, .80, phase)
			wing_open = .34 + .55 * warning
			bank = -.29 * warning
			crouch = .26 * warning
			look = .28 * warning
		_:
			look = .11 * sin(TAU * phase)
			wing_open += .06 * sin(PI * phase)
	turn_world(rig, RootJoint, Vector3.RIGHT, .28 * crouch)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .22 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .30 * folded)
	turn_world(rig, "bip01 spine2", Vector3.UP, -.21 * bank)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.38 * folded)
	turn_world(rig, "bip01 head", Vector3.UP, look)
	turn_world(rig, "wing_connector", Vector3.BACK, bank * .38)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var prefix := "gargoyle %s " % side
		turn_world(rig, prefix + "mainwing1", Vector3.BACK, sign_x * (.68 * folded - 1.39 * wing_open) + .54 * bank)
		turn_world(rig, prefix + "mainwing1", Vector3.UP, sign_x * (.55 * folded - .30 * wing_open))
		turn_world(rig, prefix + "mainwing2", Vector3.BACK, sign_x * (.41 * folded - .21 * wing_open))
		for joint: String in ["wing1", "wing2", "wing3", "wing4"]:
			turn_world(rig, prefix + joint, Vector3.UP, sign_x * (.24 * folded - .16 * wing_open))
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.60 * crouch)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, 1.00 * crouch)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.66 * crouch)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign_x * (-.34 * warning + .21 * folded))
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.51 * folded - .23 * warning)
	anchor_hind_paws(rig, anchor)

func place_gargoyle(motion: Animation, rig: Skeleton3D, group: int) -> void:
	if group == 23:
		offset_root(motion, rig, func(phase: float): return .24 * envelope(phase, .25, .58, .73, .98))

func pose_headless(rig: Skeleton3D, phase: float, group: int) -> void:
	var anchor := hind_midpoint(rig)
	var hip := joint_world(rig, RootJoint)
	var left := joint_world(rig, "bip01 l hand")
	var right := joint_world(rig, "bip01 r hand")
	var gather := 0.0
	var rise := 0.0
	var brace := 0.0
	if group == 23:
		gather = 1.0 - smoothstep(.28, .92, phase)
		rise = smoothstep(.62, 1.0, phase)
	else:
		brace = smoothstep(.02, .75, phase)
		rise = .38 * brace
	turn_world(rig, RootJoint, Vector3.RIGHT, .18 * gather - .19 * rise)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .13 * gather - .26 * rise)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .09 * gather - .19 * rise)
	turn_world(rig, "bip01 spine2", Vector3.UP, -.39 * brace)
	turn_world(rig, "bip01 spine3", Vector3.BACK, -.17 * brace)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.27 * rise)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.26 * gather + .29 * rise)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.BACK, sign_x * -.14 * brace)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .31 * gather - .29 * rise)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.18 * gather + .19 * rise)
		turn_world(rig, "bip01 %s hand" % side, Vector3.UP, sign_x * .24 * gather)
	var held := hip + Vector3(.43, .13, .59)
	fit_arm(rig, "l", left.lerp(hip + Vector3(.20, -.30, .84), gather).lerp(held, maxf(rise, brace)))
	fit_arm(rig, "r", right.lerp(hip + Vector3(-.23, -.25, .89), gather).lerp(hip + Vector3(-.65, .38, .43), brace))
	anchor_hind_paws(rig, anchor)
