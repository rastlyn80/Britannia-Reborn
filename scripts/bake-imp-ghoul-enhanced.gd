# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-serpent-harpy-enhanced.gd"

const ImpGhoulStage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/imp-ghoul/"
const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const ImpClips := {12: "ImpWingFlick", 23: "ImpUnfurl", 26: "ImpQuietHover", 27: "ImpGlideFeint", 28: "ImpWingAlert"}
const ImpLengths := {12: .71, 23: 1.13, 26: 1.0, 27: .98, 28: .55}
const GhoulClips := {23: "GhoulKneelingRise", 28: "GhoulCrookedReach"}
const GhoulLengths := {23: 1.03, 28: .84}
const Limbs := [RootJoint, "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 spine3", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm", "bip01 l hand", "bip01 r hand",
	"bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf", "bip01 l foot", "bip01 r foot"]

func run() -> void:
	var ghoul := Registry.entry(153).duplicate(true)
	ghoul.assets = Profile.registered_assets(ghoul)
	Registry.entries[153] = ghoul
	prepare_body(74, ImpClips, ImpLengths, Limbs + ["imp_l_wing 01", "imp_r_wing 01", "imp_l_wing 02", "imp_r_wing 02"],
		pose_imp, ImpGhoulStage, place_imp)
	prepare_body(153, GhoulClips, GhoulLengths, Limbs + ["box01", "box02", "box03", "box04"], pose_ghoul, ImpGhoulStage)
	quit()

func pose_imp(rig: Skeleton3D, phase: float, group: int) -> void:
	var anchor := hind_midpoint(rig)
	var pitch := 0.0
	var bank := 0.0
	var fold := 0.0
	var spread := 0.0
	var flick := 0.0
	match group:
		12:
			spread = .52 + .12 * sin(PI * phase)
			bank = .56 * (1.0 - .28 * sin(PI * phase))
			pitch = .37 - .19 * sin(PI * phase)
		23:
			fold = 1.0 - smoothstep(.01, .48, phase)
			spread = .67 * smoothstep(.11, .52, phase)
			flick = .74 * sin((phase - .14) * TAU * 2.2) * sin(PI * phase)
		27:
			spread = .49 + .40 * sin(PI * phase)
			pitch = .59 * envelope(phase, .10, .39, .68, .96)
			bank = .37 * sin(TAU * phase)
		28:
			spread = .63 * smoothstep(.04, .66, phase)
			pitch = .30 * spread
			bank = .41 * spread
		_:
			fold = .34 + .11 * sin(TAU * phase)
			turn_world(rig, "bip01 head", Vector3.UP, .16 * sin(PI * phase))
	turn_world(rig, RootJoint, Vector3.RIGHT, pitch + .36 * fold)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .22 * fold)
	turn_world(rig, "bip01 spine2", Vector3.BACK, .32 * bank)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.24 * pitch - .19 * fold)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		turn_world(rig, "imp_%s_wing 01" % side, Vector3.BACK, sign_x * (.38 * spread + flick - .58 * fold) + bank)
		turn_world(rig, "imp_%s_wing 01" % side, Vector3.UP, sign_x * (.47 * fold - .14 * spread))
		turn_world(rig, "imp_%s_wing 02" % side, Vector3.BACK, -sign_x * (.27 * spread + .62 * flick))
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, -sign_x * (.31 * spread - .26 * fold))
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.50 * fold - .39 * spread)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.43 * fold + .21 * spread)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .72 * fold - .36 * spread)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.40 * fold + .19 * spread)
	anchor_hind_paws(rig, anchor)

func place_imp(motion: Animation, rig: Skeleton3D, group: int) -> void:
	var rest_lift := .13 if group == 26 else .09
	var pulse_lift := {12: .12, 23: .36, 26: .04, 27: .21, 28: .13}
	offset_root(motion, rig, func(phase: float): return rest_lift + pulse_lift[group] * sin(PI * phase))

func pose_ghoul(rig: Skeleton3D, phase: float, group: int) -> void:
	var anchor := hind_midpoint(rig)
	var hip := joint_world(rig, RootJoint)
	var left := joint_world(rig, "bip01 l hand")
	var right := joint_world(rig, "bip01 r hand")
	var kneel := (1.0 - smoothstep(.09, .67, phase)) if group == 23 else 0.0
	var rise := smoothstep(.15, .82, phase) if group == 23 else 0.0
	var reach := smoothstep(.02, .81, phase) if group == 28 else 0.0
	turn_world(rig, RootJoint, Vector3.RIGHT, .17 * kneel - .23 * rise)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .16 * kneel - .27 * rise)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.21 * rise)
	turn_world(rig, "bip01 spine2", Vector3.UP, .39 * reach)
	turn_world(rig, "bip01 spine3", Vector3.BACK, -.14 * reach)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.26 * kneel + .12 * rise)
	turn_world(rig, "bip01 head", Vector3.UP, .29 * reach)
	for side: String in ["l", "r"]:
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.30 * kneel + .25 * rise)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .54 * kneel - .35 * rise)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.32 * kneel + .16 * rise)
	for panel: String in ["box01", "box02", "box03", "box04"]:
		turn_world(rig, panel, Vector3.RIGHT, .16 * kneel - .18 * rise)
		turn_world(rig, panel, Vector3.UP, .16 * reach)
	fit_arm(rig, "r", right.lerp(hip + Vector3(-.35, -.32, .78), kneel).lerp(hip + Vector3(-.42, .67, .69), reach))
	fit_arm(rig, "l", left.lerp(hip + Vector3(.27, -.16, .72), kneel).lerp(hip + Vector3(.52, .22, .42), reach))
	anchor_hind_paws(rig, anchor)
