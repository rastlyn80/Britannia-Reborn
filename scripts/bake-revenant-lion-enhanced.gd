# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/revenant-lion-enhanced/"
const Body := 251
const Clips := {4: "RevenantLionPounce", 15: "RevenantLionShortSnarl", 23: "RevenantLionRise",
	25: "RevenantLionQuietStand", 26: "RevenantLionScentDip", 27: "RevenantLionChallenge",
	28: "RevenantLionLowGuard"}
const Durations := {4: .89, 15: .60, 23: 1.03, 25: 1.12, 26: 1.05, 27: .96, 28: .74}
const LionJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 neck", "bip01 head", "jawbone",
	"bip01 l clavicle", "bip01 r clavicle", "bip01 l upperarm", "bip01 r upperarm",
	"bip01 l forearm", "bip01 r forearm", "bip01 l hand", "bip01 r hand",
	"bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf", "bip01 l horselink",
	"bip01 r horselink", "bip01 l foot", "bip01 r foot"]


func run() -> void:
	prepare_body(Body, Clips, Durations, LionJoints, pose_lion, Destination, configure_motion)
	quit()


func configure_motion(motion: Animation, _rig: Skeleton3D, group: int) -> void:
	if group == 25:
		motion.loop_mode = Animation.LOOP_LINEAR


func pose_lion(rig: Skeleton3D, phase: float, group: int) -> void:
	var crouch := 0.0
	var reach := 0.0
	var lift := 0.0
	var dip := 0.0
	var yaw := 0.0
	var open_jaw := 0.0
	var lead := 0.0
	match group:
		4:
			crouch = .62 * envelope(phase, .02, .20, .27, .44)
			reach = envelope(phase, .26, .45, .61, .87)
			lift = .57 * envelope(phase, .23, .40, .48, .65)
			dip = .14 * crouch - .18 * lift
			open_jaw = .39 * reach
			lead = .13 * reach
		15:
			var bark := envelope(phase, .03, .35, .52, .92)
			crouch = .12 * bark
			dip = -.20 * bark
			open_jaw = .38 * bark
		23:
			crouch = .91 * (1.0 - smoothstep(.31, .94, phase))
			reach = .46 * envelope(phase, .15, .37, .55, .78)
			dip = -.11 * crouch - .13 * reach
			lead = .14 * reach
		25:
			var breath := sin(TAU * phase)
			crouch = .025 * (1.0 - cos(TAU * phase))
			dip = .028 * breath
			yaw = .036 * breath
		26:
			var sniff := envelope(phase, .03, .31, .68, .98)
			crouch = .23 * sniff
			dip = .29 * sniff
			yaw = .15 * sin(TAU * phase) * sniff
		27:
			var challenge := envelope(phase, .11, .43, .65, .99)
			lift = .23 * challenge
			dip = -.32 * challenge
			yaw = .24 * challenge
			open_jaw = .73 * challenge
			lead = .21 * challenge
		28:
			var guard := smoothstep(.11, .73, phase)
			crouch = .52 * guard
			reach = .18 * guard
			dip = .15 * guard
			yaw = -.15 * guard
	var hind_anchor := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.RIGHT, .15 * crouch - .50 * lift)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .13 * crouch - .18 * lift)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .18 * crouch - .19 * lift)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, dip - .07 * reach)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.14 * dip + .10 * lift)
	turn_world(rig, "bip01 neck", Vector3.UP, yaw * .39)
	turn_world(rig, "bip01 head", Vector3.UP, yaw * .61)
	turn_world(rig, "jawbone", Vector3.RIGHT, open_jaw)
	for side: String in ["l", "r"]:
		var bias := lead if side == "l" else -lead
		turn_world(rig, "bip01 %s clavicle" % side, Vector3.RIGHT, -.13 * reach - bias)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.33 * crouch - .48 * reach + bias)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, .26 * crouch + .30 * lift - .13 * reach)
		turn_world(rig, "bip01 %s hand" % side, Vector3.RIGHT, -.24 * crouch + .18 * reach)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.30 * crouch + .39 * lift)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .36 * crouch - .14 * lift)
		turn_world(rig, "bip01 %s horselink" % side, Vector3.RIGHT, -.15 * crouch + .11 * reach)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.06 * reach)
	anchor_hind_paws(rig, hind_anchor)
