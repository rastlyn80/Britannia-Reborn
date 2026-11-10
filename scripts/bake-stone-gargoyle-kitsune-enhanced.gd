# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-gargoyle-headless-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/stone-gargoyle-bake-kitsune/"
const Stone := {12: "StoneGargoyleRisingRake", 23: "StoneGargoyleUnbrace", 26: "StoneGargoyleClawCheck",
	27: "StoneGargoyleStaggeredFeint", 28: "StoneGargoyleHunchedAlert"}
const Kitsune := {4: "BakeKitsuneLowSnap", 15: "BakeKitsuneSkiddingRecoil", 25: "BakeKitsuneQuietStand",
	26: "BakeKitsuneScentCheck", 27: "BakeKitsuneThreeTailFeint", 28: "BakeKitsuneStillAlert"}
const StoneLengths := {12: .77, 23: 1.03, 26: 1.23, 27: 1.14, 28: .68}
const KitsuneLengths := {4: .72, 15: .83, 25: 1.23, 26: 1.54, 27: 1.14, 28: .68}
const TailJoints := ["bip01 tail", "bip01 tail1", "l_tailbone", "l_tailbone01", "m_tailbone", "m_tailbone01"]
const KitsuneJoints := ["bip01", "bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 neck", "bip01 head", "jawbone",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm",
	"bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf", "bip01 l foot", "bip01 r foot"]


func run() -> void:
	var stone_wings := ["bip01 head", "wing_connector", "bip01 r clavicle", "bip01 l clavicle"]
	for side: String in ["l", "r"]:
		for joint: String in Membrane:
			stone_wings.append("gargoyle %s %s" % [side, joint])
	prepare_body(67, Stone, StoneLengths, Limbs + stone_wings, pose_stone, Destination)
	prepare_body(246, Kitsune, KitsuneLengths, KitsuneJoints + TailJoints, pose_kitsune, Destination)
	quit()


func pose_stone(rig: Skeleton3D, phase: float, group: int) -> void:
	var crouch := 0.0
	var twist := 0.0
	var rake := 0.0
	var check := 0.0
	var lunge := 0.0
	var spread := 0.0
	match group:
		12:
			rake = envelope(phase, .01, .25, .35, .68)
			lunge = .76 * envelope(phase, .27, .59, .72, .99)
			twist = -.39 * rake + .52 * lunge
			spread = .52 * rake + .69 * lunge
			crouch = .26 + .42 * lunge - .21 * rake
		23:
			crouch = 1.0 - smoothstep(.15, .97, phase)
			check = .51 * crouch
		26:
			check = .79 * envelope(phase, .07, .31, .72, .99)
			crouch = .15 * check
			twist = -.16 * check
		27:
			lunge = envelope(phase, .12, .45, .59, .93)
			twist = .36 - .73 * lunge
			spread = .78 * lunge
			crouch = .23 + .35 * lunge
		28:
			spread = .75 * smoothstep(.10, .55, phase)
			crouch = .52 * smoothstep(.06, .53, phase)
			lunge = .49 * spread
			twist = .22 * spread
	var feet: Array[Transform3D] = []
	for side: String in ["l", "r"]:
		var foot := rig.get_bone_global_pose(rig.find_bone("bip01 %s foot" % side))
		if side == "r":
			foot.origin += rig.global_basis.inverse() * Vector3(-.12 * spread, .39 * maxf(rake, lunge), -.21 * lunge)
		feet.append(foot)
	var pelvis := rig.find_bone(RootJoint)
	var hips := rig.get_bone_global_pose(pelvis)
	hips.origin += rig.global_basis.inverse() * Vector3(-.15 * twist, -.60 * crouch, .19 * lunge)
	rig.set_bone_global_pose(pelvis, hips)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .32 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .38 * crouch - .24 * rake)
	turn_world(rig, "bip01 spine2", Vector3.UP, twist)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .42 * check - .36 * crouch)
	turn_world(rig, "bip01 head", Vector3.UP, -.46 * twist)
	var chest := joint_world(rig, "bip01 spine2")
	for index in 2:
		var side := "l" if index == 0 else "r"
		var sign_x := 1.0 if index == 0 else -1.0
		fit_foot(rig, side, feet[index])
		var hand := joint_world(rig, "bip01 %s hand" % side)
		hand = hand.lerp(chest + Vector3(sign_x * .18, -.40, .34), check)
		hand = hand.lerp(chest + Vector3(sign_x * .64, .10 + .12 * sign_x * twist, .23), spread)
		if side == "r":
			hand = hand.lerp(chest + Vector3(-.25, .74, .04), rake)
			hand = hand.lerp(chest + Vector3(-.50, -.36, .65), .82 * lunge)
		fit_arm(rig, side, hand)
		fold_stone_wing(rig, side, sign_x, crouch, twist)


func fold_stone_wing(rig: Skeleton3D, side: String, sign_x: float, crouch: float, twist: float) -> void:
	var prefix := "gargoyle %s " % side
	# The registered gestures have a compact back silhouette. Tuck the original
	# wings behind the ribs while the separate flight motions remain unchanged.
	turn_world(rig, prefix + "mainwing1", Vector3.RIGHT, -.30 - .08 * crouch)
	turn_world(rig, prefix + "mainwing1", Vector3.BACK, sign_x * -.35 + .07 * twist)
	turn_world(rig, prefix + "mainwing2", Vector3.RIGHT, .40 - .06 * crouch)
	turn_world(rig, prefix + "mainwing2", Vector3.UP, sign_x * .50)
	for joint: String in ["wing1", "wing2", "wing3", "wing4"]:
		turn_world(rig, prefix + joint, Vector3.RIGHT, .44 + .10 * crouch)
	turn_world(rig, prefix + "mainwing2", Vector3.RIGHT, .65)


func pose_kitsune(rig: Skeleton3D, phase: float, group: int) -> void:
	var dip := 0.0
	var reach := 0.0
	var recoil := 0.0
	var head_lift := 0.0
	var look := 0.0
	var splay := 0.0
	match group:
		4:
			dip = .37 + .35 * envelope(phase, .03, .19, .31, .54)
			reach = envelope(phase, .08, .26, .45, .84)
			head_lift = .26 * reach
			splay = .49 * reach
		15:
			dip = .40 + .39 * envelope(phase, .03, .28, .53, .93)
			recoil = envelope(phase, .06, .32, .62, 1.0)
			look = -.26 * recoil
			splay = .60 * recoil
		25:
			dip = .21 + .035 * sin(TAU * phase)
			head_lift = .07 * sin(PI * phase)
		26:
			dip = .27 + .28 * envelope(phase, .09, .31, .64, .91)
			look = .37 * sin(TAU * phase) * sin(PI * phase)
			splay = .77 * envelope(phase, .08, .34, .65, .93)
		27:
			dip = .43 - .20 * sin(PI * phase)
			head_lift = .59 * envelope(phase, .12, .42, .62, .95)
			look = -.22 * sin(TAU * phase)
			splay = .88 * sin(PI * phase)
		28:
			dip = .32
			look = -.24 * smoothstep(.09, .76, phase)
			head_lift = .26 * smoothstep(.08, .77, phase)
			splay = .22 * sin(PI * phase)
	var anchor := hind_midpoint(rig)
	turn_world(rig, "bip01", Vector3.RIGHT, .14 * dip - .20 * recoil)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .16 * dip)
	turn_world(rig, "bip01 spine1", Vector3.UP, .24 * look)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .23 * dip - .69 * head_lift)
	turn_world(rig, "bip01 head", Vector3.UP, .77 * look)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.30 * head_lift)
	turn_world(rig, "jawbone", Vector3.RIGHT, .46 * reach + .17 * recoil)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var stride := reach * (1.0 if side == "l" else .43)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.61 * stride - .38 * recoil - .19 * dip)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, .36 * stride + .51 * recoil + .34 * dip)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign_x * .11 * recoil)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.30 * dip + .16 * stride)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .36 * dip)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.18 * dip)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.46 + .23 * splay + .18 * reach)
	turn_world(rig, "bip01 tail", Vector3.UP, .34 * splay - .40 * look)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, .20 * recoil - .29 * splay)
	turn_world(rig, "l_tailbone", Vector3.UP, -.44 * splay - .38 * look)
	turn_world(rig, "l_tailbone", Vector3.RIGHT, .45 + .10 * dip)
	turn_world(rig, "l_tailbone01", Vector3.RIGHT, .11 - .18 * splay + .23 * recoil)
	turn_world(rig, "m_tailbone", Vector3.UP, .13 * splay - .51 * look)
	turn_world(rig, "m_tailbone01", Vector3.RIGHT, .29 * splay + .16 * reach)
	anchor_hind_paws(rig, anchor)
