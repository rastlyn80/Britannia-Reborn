# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/terathan-matriarch-swamp-dragons/"
const Loose := {1: "SwampDragonWingStand", 4: "SwampDragonLowSnap", 11: "SwampDragonWingFlare",
	15: "SwampDragonWingSweep", 23: "SwampDragonUnfold", 26: "SwampDragonHeadCheck",
	27: "SwampDragonWingShake", 28: "SwampDragonWingAlert", 31: "SwampDragonSeatedStill"}
const Barded := {11: "BardedSwampDragonNeckFlare", 12: "BardedSwampDragonBraceLunge",
	15: "BardedSwampDragonLowSweep", 23: "BardedSwampDragonRise", 26: "BardedSwampDragonHeadCheck",
	27: "BardedSwampDragonTailShake", 28: "BardedSwampDragonAlert", 31: "BardedSwampDragonSeatedStill"}
const Lengths := {1: .90, 4: .72, 11: 1.14, 12: 1.00, 15: .55, 23: .91,
	26: 1.10, 27: .82, 28: .64, 31: .91}
const Neck := ["bip01 neck", "bip01 neck1", "bip01 neck2", "bip01 neck3", "bip01 neck4", "bip01 head"]
const Tail := ["bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3", "bip01 tail4"]
const WingRoots := ["wing_r21", "wing_r15"]
const WingElbows := ["dummy39", "dummy34"]
const Forelegs := ["bip01 l upperarm", "bip01 l forearm", "bip01 r upperarm", "bip01 r forearm"]
const DragonJoints := ["bip01 spine1", "bip01 spine2", "bone_jaw1"] + Neck + Tail + WingRoots + WingElbows + Forelegs


func run() -> void:
	prepare_body(794, Loose, Lengths, DragonJoints, pose_dragon.bind(false), Destination)
	prepare_body(799, Barded, Lengths, DragonJoints, pose_dragon.bind(true), Destination)
	quit()


func pose_dragon(rig: Skeleton3D, phase: float, group: int, barded: bool) -> void:
	var nod := 0.0
	var lift := 0.0
	var yaw := 0.0
	var jaw := 0.0
	var tail := 0.0
	var fold := 0.0
	var wingbeat := 0.0
	var crouch := 0.0
	var pulse := sin(PI * phase)
	var rhythm := sin(TAU * phase) * pulse
	match group:
		1:
			wingbeat = .095 * rhythm
			tail = .12 * rhythm
			nod = .04 * pulse
		4:
			var snap := envelope(phase, .22, .45, .53, .89)
			nod = .33 * snap
			jaw = .54 * snap
			tail = -.19 * snap
			wingbeat = -.34 * snap
		11:
			var flare := envelope(phase, .02, .28, .55, .91)
			lift = .30 * flare
			jaw = .26 * flare
			tail = .22 * flare
			wingbeat = .48 * flare
		12:
			lift = .41 * envelope(phase, .01, .21, .31, .55)
			nod = .46 * smoothstep(.29, .84, phase)
			crouch = .17 * smoothstep(.37, .83, phase)
			jaw = .49 * envelope(phase, .21, .43, .57, .87)
			tail = -.32 * pulse
		15:
			nod = .24 * pulse
			yaw = .13 * rhythm
			fold = .42 * pulse
			tail = .25 * pulse
		23:
			var emergence := 1.0 - smoothstep(.11, .63, phase)
			crouch = .57 * emergence
			nod = .61 * emergence
			fold = 1.0 * emergence
			tail = -.37 * emergence
			wingbeat = .18 * envelope(phase, .31, .63, .72, .95)
		26:
			lift = .24 * envelope(phase, .02, .31, .55, .93)
			yaw = .32 * rhythm
			wingbeat = .095 * pulse
		27:
			wingbeat = .31 * sin(TAU * 1.30 * phase) * pulse
			tail = .53 * sin(TAU * 1.30 * phase) * pulse
			nod = .13 * pulse
		28:
			wingbeat = .26 * smoothstep(.09, .76, phase)
			yaw = .25 * smoothstep(.05, .86, phase)
			tail = .21 * pulse
			lift = .13 * smoothstep(.28, .87, phase)
		31:
			fold = .88
			nod = .04 * pulse
			yaw = .08 * rhythm
			tail = .12 * rhythm
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, -.08 * lift - .12 * crouch)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .28 * nod - .35 * lift)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .33 * nod - .33 * lift)
	turn_world(rig, "bip01 neck2", Vector3.RIGHT, .41 * nod - .44 * lift)
	turn_world(rig, "bip01 neck3", Vector3.UP, .48 * yaw)
	turn_world(rig, "bip01 neck4", Vector3.UP, .45 * yaw)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.15 * nod - .37 * lift)
	turn_world(rig, "bip01 head", Vector3.UP, .61 * yaw)
	turn_world(rig, "bone_jaw1", Vector3.RIGHT, jaw)
	for segment in Tail.size():
		turn_world(rig, Tail[segment], Vector3.UP, tail * (.24 + .08 * segment))
		turn_world(rig, Tail[segment], Vector3.RIGHT, -.18 * tail)
	for side in 2:
		turn_world(rig, Forelegs[side * 2], Vector3.RIGHT, -.42 * crouch)
		turn_world(rig, Forelegs[side * 2 + 1], Vector3.RIGHT, .77 * crouch)
		if barded:
			continue
		var outward := 1.0 if side == 0 else -1.0
		turn_world(rig, WingRoots[side], Vector3.FORWARD, outward * (wingbeat - .42 * fold))
		turn_world(rig, WingRoots[side], Vector3.UP, outward * .72 * fold)
		turn_world(rig, WingElbows[side], Vector3.UP, outward * .51 * fold)
		turn_world(rig, WingElbows[side], Vector3.FORWARD, outward * (.30 * wingbeat - .35 * fold))
