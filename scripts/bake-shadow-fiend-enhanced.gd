# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-imp-ghoul-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/shadow-fiend-enhanced/"
const Body := 168
const Clips := {11: "ShadowFiendShoulderFeint", 12: "ShadowFiendRaisedClaws", 15: "ShadowFiendHighWard",
	23: "ShadowFiendManifest", 25: "ShadowFiendQuietStand", 26: "ShadowFiendScentTurn",
	27: "ShadowFiendTwistedGuard", 28: "ShadowFiendOpenGuard"}
const Durations := {11: .70, 12: .80, 15: .64, 23: 1.17, 25: 1.14, 26: 1.04, 27: .96, 28: .77}
const ShadowJoints := Limbs + ["imp_l_wing 01", "imp_r_wing 01", "imp_l_wing 02", "imp_r_wing 02"]


func run() -> void:
	var row := Registry.entry(Body)
	var original := row.duplicate(true)
	row.assets = Profile.registered_assets(row)
	Registry.entries[Body] = row
	prepare_body(Body, Clips, Durations, ShadowJoints, pose_shadow, Destination, configure_shadow)
	Registry.entries[Body] = original
	quit()


func configure_shadow(motion: Animation, _rig: Skeleton3D, group: int) -> void:
	if group == 25:
		motion.loop_mode = Animation.LOOP_LINEAR


func pose_shadow(rig: Skeleton3D, phase: float, group: int) -> void:
	var fold := 0.0
	var bow := 0.0
	var spread := 0.0
	var lift := 0.0
	var twist := 0.0
	var reach := 0.0
	match group:
		11:
			var feint := envelope(phase, .03, .33, .55, .95)
			bow = .72 * feint
			twist = -.29 * feint
			reach = .39 * feint
		12:
			var threat := envelope(phase, .03, .43, .58, .95)
			lift = .83 * threat
			spread = .46 * threat
			bow = -.32 * threat
			reach = .55 * envelope(phase, .42, .61, .74, .96)
		15:
			var ward := 1.0 - smoothstep(.35, .94, phase)
			lift = .76 * ward
			spread = .25 * ward
			bow = -.26 * ward
			reach = .30 * ward
		23:
			fold = 1.0 - smoothstep(.16, .80, phase)
			spread = .41 * envelope(phase, .37, .59, .78, .98)
			lift = .20 * spread
		25:
			bow = .028 * sin(TAU * phase)
			spread = .025 * (1.0 - cos(TAU * phase))
			twist = .031 * sin(TAU * phase)
		26:
			var inspection := envelope(phase, .06, .38, .56, .96)
			twist = .34 * inspection
			bow = .21 * inspection
			spread = .34 * inspection
		27:
			var sweep := envelope(phase, .04, .33, .58, .96)
			spread = .43 * sweep
			lift = .52 * sweep
			twist = .49 * sin(TAU * phase) * sweep
			bow = -.34 * sweep
		28:
			var guard := smoothstep(.11, .74, phase)
			spread = .48 * guard
			lift = .16 * guard
			bow = .19 * guard
	var anchor := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.RIGHT, .29 * fold + .14 * bow)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .30 * fold + .28 * bow)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, .27 * fold + .31 * bow)
	turn_world(rig, "bip01 spine3", Vector3.UP, twist)
	turn_world(rig, "bip01 head", Vector3.UP, twist * .42)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.21 * fold - .18 * bow)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign_x * (.68 * spread + .27 * lift - .14 * fold))
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.62 * lift - .43 * reach)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.69 * lift - .32 * reach - .33 * fold)
		turn_world(rig, "bip01 %s hand" % side, Vector3.UP, sign_x * (.20 * spread + .31 * reach))
		turn_world(rig, "imp_%s_wing 01" % side, Vector3.UP, sign_x * (.16 + .49 * fold - .16 * spread))
		turn_world(rig, "imp_%s_wing 02" % side, Vector3.BACK, -sign_x * (.24 * fold + .17 * spread))
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.42 * fold)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .59 * fold)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.17 * fold)
	anchor_hind_paws(rig, anchor)
