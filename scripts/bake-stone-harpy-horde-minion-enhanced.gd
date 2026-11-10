# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-serpent-harpy-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/stone-harpy-horde-minion/"
const Stone := {11: "StoneHarpyFoldAndSweep", 12: "StoneHarpyDoubleWingbeat", 15: "StoneHarpyShieldAndFlare",
	23: "StoneHarpyFoldedLaunch", 26: "StoneHarpyNarrowWatch", 27: "StoneHarpyBankedSpread", 28: "StoneHarpyOpenAlert"}
const Horde := {12: "HordeMinionOverheadLunge", 23: "HordeMinionUncurl", 26: "HordeMinionUneasyWatch",
	27: "HordeMinionGraspingGuard", 28: "HordeMinionRaisedClawAlert"}
const StoneLengths := {11: .93, 12: 1.06, 15: .75, 23: 1.14, 26: 1.15, 27: 1.16, 28: .94}
const HordeLengths := {12: .95, 23: .96, 26: 1.14, 27: 1.06, 28: .86}
const HordeJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head", "bone_jaw",
	"bip01 ponytail1", "bip01 ponytail2", "bip01 l clavicle", "bip01 r clavicle",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]


func run() -> void:
	prepare_body(73, Stone, StoneLengths, HarpyJoints, pose_stone_harpy, Destination, fit_stone_lift)
	prepare_body(776, Horde, HordeLengths, HordeJoints, pose_horde_minion, Destination)
	quit()


func pose_stone_harpy(rig: Skeleton3D, phase: float, group: int) -> void:
	var spread := 0.0
	var fold := 0.0
	var flap := 0.0
	var bank := 0.0
	var tuck := 0.0
	var turn := 0.0
	match group:
		11:
			fold = .96 * envelope(phase, .02, .23, .53, .74)
			spread = .66 * (1.0 - fold) + .22 * smoothstep(.77, .97, phase)
			tuck = .67 * fold
			bank = -.22 * sin(TAU * phase)
		12:
			spread = .46
			flap = .80 * sin(2.0 * TAU * phase + .30)
			tuck = .70 * envelope(phase, .08, .42, .59, .91)
			bank = .19 * sin(TAU * phase)
		15:
			fold = .87 * (1.0 - smoothstep(.53, .92, phase))
			spread = .44 * smoothstep(.43, .95, phase)
			tuck = .39 * envelope(phase, .03, .27, .59, .98)
			bank = -.45 * envelope(phase, .0, .27, .68, 1.0)
		23:
			fold = .97 * (1.0 - smoothstep(.02, .31, phase))
			spread = .93 * smoothstep(.04, .33, phase) - .37 * smoothstep(.53, .86, phase)
			flap = .32 * envelope(phase, .12, .40, .55, .81)
			tuck = .37 * envelope(phase, .14, .41, .66, .99)
		26:
			fold = .72 + .06 * sin(TAU * phase)
			turn = -.47 * sin(TAU * phase) * sin(PI * phase)
		27:
			spread = .89 - .21 * smoothstep(.53, .86, phase)
			bank = -.34 * smoothstep(.09, .79, phase)
			flap = .26 * cos(TAU * phase)
			tuck = .46
		28:
			fold = .47 * (1.0 - smoothstep(.04, .36, phase))
			spread = .76 * smoothstep(.05, .55, phase)
			flap = .34 * sin(PI * phase) * spread
			tuck = .30 * spread
	var anchor := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.FORWARD, bank * .58)
	var pitch := .21 * fold + .12 * tuck
	if group == 11:
		pitch += .26 * fold
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, pitch)
	turn_world(rig, "bip01 neck", Vector3.UP, .40 * turn)
	turn_world(rig, "bip01 head", Vector3.UP, .60 * turn)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.39 * tuck + .16 * fold)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var arm_angle := sign_x * (.75 * spread + flap - .83 * fold) + .70 * bank
		turn_world(rig, "bip01 %s clavicle" % side, Vector3.BACK, .14 * arm_angle)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, .85 * arm_angle)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.UP, sign_x * (.20 * spread - .59 * fold))
		turn_world(rig, "harpy %s elbowextension" % side, Vector3.UP, sign_x * (.18 * spread - .29 * fold))
		turn_world(rig, "bip01 %s hand" % side, Vector3.BACK, -.31 * arm_angle - sign_x * (.14 * fold + .19 * flap))
		var curl := tuck * (1.0 + sign_x * .75 * bank)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.47 * curl)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .71 * curl)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.29 * curl)
	anchor_hind_paws(rig, anchor)


func fit_stone_lift(motion: Animation, rig: Skeleton3D, group: int) -> void:
	var lift: Vector4 = {
		11: Vector4(.13, .31, .61, .94), 12: Vector4(.01, .23, .68, 1.0),
		15: Vector4(.06, .38, .62, 1.0), 23: Vector4(.07, .42, .53, .95),
		27: Vector4(.02, .25, .67, .98),
	}.get(group, Vector4.ZERO)
	if not lift.is_zero_approx():
		var amount: float = {11: .22, 12: .35, 15: .16, 23: .55, 27: .19}[group]
		offset_root(motion, rig, func(phase: float): return amount * envelope(phase, lift.x, lift.y, lift.z, lift.w))


func pose_horde_minion(rig: Skeleton3D, phase: float, group: int) -> void:
	var fold := 0.0
	var raise_arms := 0.0
	var reach := 0.0
	var open := 0.0
	var yaw := 0.0
	match group:
		12:
			raise_arms = envelope(phase, .02, .31, .54, .77)
			reach = smoothstep(.49, .79, phase)
			fold = .62 * reach
			yaw = .25 * raise_arms
		23:
			fold = .91 * (1.0 - smoothstep(.01, .36, phase))
			raise_arms = .72 * envelope(phase, .06, .30, .49, .73)
			open = .66 * envelope(phase, .19, .47, .65, .90)
			reach = .29 * envelope(phase, .46, .71, .80, 1.0)
		26:
			fold = .14 + .041 * sin(TAU * phase)
			yaw = .24 * sin(TAU * phase) * sin(PI * phase)
		27:
			fold = .39 * (1.0 - smoothstep(.30, .91, phase))
			reach = .46 * envelope(phase, .01, .21, .41, .66)
			open = .70 * smoothstep(.26, .81, phase)
			yaw = .37 * sin(PI * phase)
		28:
			open = .69 * smoothstep(.11, .85, phase)
			raise_arms = .32 * smoothstep(.48, .91, phase)
			yaw = -.19 * smoothstep(.22, .73, phase)
	var feet: Array[Transform3D] = []
	for side: String in ["l", "r"]:
		feet.append(rig.get_bone_global_pose(rig.find_bone("bip01 %s foot" % side)))
	var pelvis := rig.find_bone(RootJoint)
	var hips := rig.get_bone_global_pose(pelvis)
	hips.origin += rig.global_basis.inverse() * Vector3(.10 * yaw, -.30 * fold + .075 * raise_arms, .16 * reach)
	rig.set_bone_global_pose(pelvis, hips)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .61 * fold + .18 * reach - .21 * raise_arms)
	turn_world(rig, "bip01 spine2", Vector3.UP, .33 * yaw)
	turn_world(rig, "bip01 head", Vector3.UP, .69 * yaw)
	turn_world(rig, "bone_jaw", Vector3.RIGHT, .18 * open + .23 * reach + .10 * raise_arms)
	turn_world(rig, "bip01 ponytail1", Vector3.RIGHT, -.22 * raise_arms + .16 * fold)
	turn_world(rig, "bip01 ponytail2", Vector3.RIGHT, -.21 * raise_arms + .16 * fold)
	var chest := joint_world(rig, "bip01 spine2")
	var head := joint_world(rig, "bip01 head")
	for index in 2:
		var side := "l" if index == 0 else "r"
		var sign_x := 1.0 if index == 0 else -1.0
		fit_foot(rig, side, feet[index])
		var hand := joint_world(rig, "bip01 %s hand" % side)
		hand = hand.lerp(chest + Vector3(sign_x * .24, -.21, .33), fold)
		hand = hand.lerp(head + Vector3(sign_x * .38, .37 + sign_x * .15 * yaw, .09), raise_arms)
		hand = hand.lerp(chest + Vector3(sign_x * .37, -.18, .64), reach)
		hand = hand.lerp(chest + Vector3(sign_x * .72, .08 - .24 * sign_x * yaw, .19), open)
		fit_arm(rig, side, hand)
		turn_world(rig, "bip01 %s hand" % side, Vector3.BACK, sign_x * (.21 * open + .15 * reach))
