# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/hydra-enhanced/"
const Clips := {4: "HydraBlueHeadSnap", 5: "HydraCascadeLash", 11: "HydraTailBrace",
	12: "HydraCentralThrust", 15: "HydraFiveHeadCoil", 23: "HydraUnfurl",
	25: "HydraQuietCoil", 26: "HydraWatchfulHeads", 27: "HydraSpreadThreat", 28: "HydraLowGuard", 31: "HydraFireBreath"}
const Durations := {4: .89, 5: .97, 11: .91, 12: .92, 15: .77, 23: 1.19, 25: 1.23,
	26: 1.09, 27: .94, 28: .82, 31: 1.55}
const SideHeadChains := [
	["bip01 r upperarm", "bip01 r forearm", "bip01 r hand", "bip01 r finger0"],
	["bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 l finger0"],
	["bip01 r thigh", "bip01 r calf", "bip01 r foot", "bip01 r toe0"],
	["bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 l toe0"],
]
const CentralChain := ["bip01 neck", "bip01 neck1", "bip01 neck2", "bip01 neck3", "bip01 head", "bip01 jaw middle head"]
const Tail := ["bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3"]


func run() -> void:
	var hydra_joints := [RootJoint, "bip01 spine"] + CentralChain + Tail
	for chain: Array in SideHeadChains:
		hydra_joints.append_array(chain)
	prepare_body(265, Clips, Durations, hydra_joints, pose_hydra, Destination, configure_motion)
	quit()


func configure_motion(clip: Animation, _rig: Skeleton3D, group: int) -> void:
	if group == 25:
		clip.loop_mode = Animation.LOOP_LINEAR


func pose_hydra(rig: Skeleton3D, phase: float, group: int) -> void:
	var dip := 0.0
	var coil := 0.0
	var spread := 0.0
	var scan := 0.0
	var center_strike := 0.0
	var side_strike := 0.0
	var tail_swing := 0.0
	var openings := 0.0
	match group:
		4:
			side_strike = .75 * envelope(phase, .09, .42, .58, .95)
			spread = .16 * side_strike
			openings = .32 * side_strike
		5:
			side_strike = .65 * envelope(phase, .16, .44, .61, .97)
			center_strike = .55 * envelope(phase, .21, .56, .70, 1.0)
			tail_swing = .54 * side_strike
			openings = .38 * side_strike
		11:
			dip = .49 * envelope(phase, .04, .36, .72, .98)
			tail_swing = .78 * envelope(phase, .06, .45, .63, .98)
			spread = .30 * dip
		12:
			center_strike = 1.10 * envelope(phase, .07, .40, .67, .98)
			dip = .21 * center_strike
			spread = .22 * center_strike
			openings = .61 * center_strike
		15:
			coil = .86 * envelope(phase, .03, .35, .64, .97)
			dip = .37 * coil
			tail_swing = .46 * coil
		23:
			coil = .91 * (1.0 - smoothstep(.10, .72, phase))
			dip = .44 * coil
			spread = .32 * envelope(phase, .28, .57, .69, .97)
			tail_swing = .53 * envelope(phase, .08, .47, .66, 1.0)
		25:
			scan = .018 * sin(TAU * phase)
			dip = .022 * (1.0 - cos(TAU * phase))
			tail_swing = .02 * sin(TAU * phase)
		26:
			var watch := envelope(phase, .03, .31, .67, .99)
			scan = .28 * sin(TAU * phase) * watch
			dip = .13 * watch
			tail_swing = .16 * watch
		27:
			spread = .69 * envelope(phase, .03, .37, .67, .99)
			scan = .22 * sin(TAU * phase) * spread
			openings = .39 * spread
			tail_swing = .28 * spread
		28:
			dip = .39 * smoothstep(.12, .83, phase)
			spread = .17 * dip
			tail_swing = -.36 * dip
		31:
			center_strike = 1.12 * envelope(phase, .08, .38, .87, .99)
			spread = .18 * center_strike
			openings = .65 * center_strike
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .19 * dip + .22 * coil)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .21 * dip + .29 * center_strike)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .18 * dip + .45 * center_strike + .37 * coil)
	turn_world(rig, "bip01 neck2", Vector3.RIGHT, .11 * dip + .30 * center_strike + .34 * coil)
	turn_world(rig, "bip01 neck3", Vector3.RIGHT, -.21 * center_strike - .16 * coil)
	turn_world(rig, "bip01 neck3", Vector3.UP, .76 * scan)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.42 * center_strike - .24 * coil)
	turn_world(rig, "bip01 jaw middle head", Vector3.RIGHT, openings)
	for index in SideHeadChains.size():
		var chain: Array = SideHeadChains[index]
		var side := -1.0 if index % 2 == 0 else 1.0
		var strength := 1.0 if index == 0 else (.62 if group == 5 else .16)
		var strike := strength * side_strike
		var fold: float = coil * [.84, .65, .55, .71][index]
		var neck_tilt := .23 * dip + .35 * fold + .50 * strike
		turn_world(rig, chain[0], Vector3.RIGHT, neck_tilt)
		turn_world(rig, chain[0], Vector3.BACK, -side * (.26 * spread + .14 * fold))
		turn_world(rig, chain[1], Vector3.RIGHT, .17 * dip + .25 * fold + .35 * strike)
		turn_world(rig, chain[1], Vector3.UP, scan * (.73 if index < 2 else .44) - side * .14 * fold)
		turn_world(rig, chain[2], Vector3.RIGHT, -.31 * strike - .17 * fold)
		turn_world(rig, chain[2], Vector3.UP, side * .17 * spread)
		turn_world(rig, chain[3], Vector3.RIGHT, openings * (.48 if index == 0 else .24))
	for index in Tail.size():
		var rate := float(index + 1) / Tail.size()
		turn_world(rig, Tail[index], Vector3.UP, tail_swing * (.30 + .32 * rate))
		turn_world(rig, Tail[index], Vector3.RIGHT, (.13 + .13 * rate) * absf(tail_swing))
