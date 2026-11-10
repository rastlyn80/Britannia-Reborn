# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const ReptileCanineStage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/alligator-direwolf/"
const AlligatorClips := {1: "AlligatorLowGape", 4: "AlligatorSideSnap", 23: "AlligatorHiss",
	25: "AlligatorQuietStand", 26: "AlligatorRisingTurn", 27: "AlligatorTailCurl", 28: "AlligatorLowAlert"}
const AlligatorLengths := {1: .90, 4: .68, 23: .82, 25: 1.0, 26: 1.0, 27: .88, 28: .58}
const DireWolfClips := {4: "DireWolfForepawSnap", 15: "DireWolfLowRecoil", 25: "DireWolfQuietStand",
	26: "DireWolfScentCheck", 27: "DireWolfShortHowl", 28: "DireWolfAlert"}
const DireWolfLengths := {4: .64, 15: .70, 25: .96, 26: .95, 27: .92, 28: .60}
const NeckAndTail := ["bip01 neck1", "bip01 tail1", "bip01 tail2"]


func run() -> void:
	var joints: Array = CommonJoints.filter(func(joint: String): return not joint.begins_with("bip01 ponytail"))
	prepare_body(202, AlligatorClips, AlligatorLengths, joints + NeckAndTail + ["bip01 ponytail1"],
		pose_alligator, ReptileCanineStage)
	var wolf := Registry.entry(23).duplicate(true)
	var assets := {}
	for treatment: String in wolf.asset_sha256:
		assets[treatment] = Registry.asset_path(wolf, treatment)
	wolf.assets = assets
	Registry.entries[23] = wolf
	prepare_body(23, DireWolfClips, DireWolfLengths, joints + NeckAndTail + ["bip01 jaw"],
		pose_dire_wolf, ReptileCanineStage)
	quit()


func pose_alligator(rig: Skeleton3D, phase: float, group: int) -> void:
	var lift := 0.0
	var gape := 0.0
	var thrust := 0.0
	var head_turn := 0.0
	var tail_turn := 0.0
	var tail_tip := 0.0
	match group:
		1:
			gape = .13 + .065 * sin(TAU * phase)
			tail_turn = .11 * sin(TAU * phase)
		4:
			var coil := envelope(phase, .02, .23, .36, .61)
			thrust = envelope(phase, .28, .43, .48, .73)
			lift = .11 * thrust
			gape = .76 * envelope(phase, .15, .38, .47, .63)
			head_turn = -.54 * coil + .35 * thrust
			tail_turn = .60 * coil - .26 * thrust
			tail_tip = -.43 * coil + .19 * thrust
		23:
			var hiss := envelope(phase, .05, .41, .63, .98)
			lift = .31 * hiss
			gape = .65 * hiss
			tail_turn = .24 * sin(TAU * phase) * sin(PI * phase)
			tail_tip = -.23 * hiss
		25:
			lift = .016 * sin(TAU * phase)
			tail_turn = .031 * sin(TAU * phase)
		26:
			var turn := envelope(phase, .22, .57, .72, 1.0)
			lift = .20 * turn
			gape = .34 * turn
			head_turn = -.32 * turn
			tail_turn = .44 * turn
			tail_tip = .31 * envelope(phase, .39, .67, .84, 1.0)
		27:
			var curl := envelope(phase, .04, .38, .68, .99)
			lift = -.10 * curl
			gape = .12 + .10 * curl
			head_turn = -.19 * curl
			tail_turn = .57 * curl
			tail_tip = .46 * curl
		28:
			var brace := envelope(phase, .04, .45, .68, .99)
			lift = -.073 * brace
			head_turn = .11 * brace
			tail_turn = -.14 * brace
	var anchor := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.RIGHT, -.13 * lift)
	turn_world(rig, "bip01 spine", Vector3.UP, .31 * head_turn)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.37 * lift + .09 * thrust)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.71 * lift + .14 * thrust)
	turn_world(rig, "bip01 neck", Vector3.UP, .56 * head_turn)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, -.43 * lift)
	turn_world(rig, "bip01 head", Vector3.UP, .49 * head_turn)
	turn_world(rig, "bip01 ponytail1", Vector3.RIGHT, gape)
	turn_world(rig, "bip01 tail", Vector3.UP, .67 * tail_turn)
	turn_world(rig, "bip01 tail1", Vector3.UP, tail_turn)
	turn_world(rig, "bip01 tail2", Vector3.UP, tail_tip)
	turn_world(rig, "bip01 tail2", Vector3.RIGHT, .16 * absf(tail_turn))
	for side: String in ["l", "r"]:
		var weight := 1.0 if side == "l" else .53
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, .18 * lift - .27 * thrust * weight)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, .28 * lift + .19 * thrust * weight)
		turn_world(rig, "bip01 %s hand" % side, Vector3.RIGHT, -.21 * lift)
	anchor_hind_paws(rig, anchor)


func pose_dire_wolf(rig: Skeleton3D, phase: float, group: int) -> void:
	var crouch := 0.0
	var neck_pitch := 0.0
	var head_turn := 0.0
	var jaw := 0.0
	var reach := 0.0
	var tail_pitch := 0.0
	match group:
		4:
			var snap := envelope(phase, .08, .33, .43, .72)
			crouch = .31 * snap
			neck_pitch = .18 * snap
			jaw = .49 * snap
			reach = .64 * snap
			tail_pitch = .34 * snap
		15:
			var recoil := 1.0 - smoothstep(.24, .88, phase)
			crouch = .59 * recoil
			neck_pitch = .19 * recoil
			reach = .26 * recoil
			tail_pitch = -.28 * recoil
		25:
			neck_pitch = .025 * sin(TAU * phase)
			tail_pitch = .045 * sin(TAU * phase)
		26:
			var scent := envelope(phase, .22, .51, .72, .98)
			crouch = .065 * scent
			neck_pitch = .15 * scent
			head_turn = .17 * envelope(phase, .31, .62, .78, 1.0)
		27:
			var howl := envelope(phase, .14, .38, .59, .91)
			neck_pitch = -.62 * howl
			jaw = .29 * howl
			tail_pitch = .22 * howl
		28:
			var alert := envelope(phase, .08, .41, .68, .99)
			neck_pitch = -.16 * alert
			head_turn = -.10 * alert
			tail_pitch = .10 * alert
	var anchor := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.RIGHT, .13 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .25 * crouch)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .39 * neck_pitch)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .26 * neck_pitch)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .39 * neck_pitch)
	turn_world(rig, "bip01 head", Vector3.UP, head_turn)
	turn_world(rig, "bip01 jaw", Vector3.RIGHT, jaw)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, .66 * tail_pitch)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, .39 * tail_pitch)
	turn_world(rig, "bip01 tail2", Vector3.UP, .48 * head_turn)
	for side: String in ["l", "r"]:
		var fore_reach := reach if side == "l" else .20 * reach
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.53 * crouch - .79 * fore_reach)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, .72 * crouch + .29 * fore_reach)
		turn_world(rig, "bip01 %s hand" % side, Vector3.RIGHT, -.20 * crouch - .17 * fore_reach)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.44 * crouch)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .46 * crouch)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, .14 * crouch)
	anchor_hind_paws(rig, anchor)
