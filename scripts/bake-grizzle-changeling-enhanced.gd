# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/interred-grizzle-changeling/"
const Grizzle := {12: "GrizzleAntlerGuard", 23: "GrizzleUncurl", 26: "GrizzleFurCheck",
	27: "GrizzleSwayThreat", 28: "GrizzleLowReach"}
const Changeling := {12: "ChangelingWingDrop", 23: "ChangelingWingRise", 26: "ChangelingHoverReach",
	27: "ChangelingWingFlourish", 28: "ChangelingTuckedHover"}
const GrizzleLengths := {12: 1.02, 23: 1.14, 26: 1.10, 27: 1.12, 28: .92}
const ChangelingLengths := {12: .93, 23: 1.22, 26: .93, 27: 1.13, 28: .74}
const Torso := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head"]


func run() -> void:
	var joints := Torso.duplicate()
	for side: String in ["l", "r"]:
		for joint: String in ["upperarm", "forearm", "hand", "thigh", "calf", "foot"]:
			joints.append("bip01 %s %s" % [side, joint])
	prepare_body(259, Grizzle, GrizzleLengths, joints + ["extrahead"], pose_grizzle, Destination)
	prepare_body(264, Changeling, ChangelingLengths, joints + ["bone_wingright", "bone_wingleft"],
		pose_changeling, Destination, set_hover)
	quit()


func pose_grizzle(rig: Skeleton3D, phase: float, group: int) -> void:
	var fold := 0.0
	var ward := 0.0
	var sweep := 0.0
	var touch := 0.0
	var swing := 0.0
	match group:
		12:
			ward = envelope(phase, .05, .25, .56, .88)
			fold = .48 * (1.0 - ward) + .23 * smoothstep(.64, .95, phase)
			sweep = .45 * envelope(phase, .50, .74, .86, 1.0)
		23:
			fold = 1.0 - smoothstep(.07, .72, phase)
			sweep = .43 * envelope(phase, .13, .36, .61, .87)
		26:
			touch = envelope(phase, .08, .34, .69, .94)
			swing = .17 * sin(TAU * phase)
		27:
			sweep = envelope(phase, .07, .48, .73, .98)
			fold = .53 * (1.0 - sweep)
			swing = .22 * sin(TAU * phase)
		28:
			sweep = smoothstep(.22, .74, phase)
			fold = .82 * sweep
	var targets: Array[Transform3D] = []
	for side: String in ["l", "r"]:
		var foot := rig.get_bone_global_pose(rig.find_bone("bip01 %s foot" % side))
		if side == "r":
			var lift := .16 * fold + .18 * sweep
			foot.origin += rig.global_basis.inverse() * Vector3(-.04 * sweep, lift, -.13 * fold)
		targets.append(foot)
	var pelvis := rig.find_bone(RootJoint)
	var hips := rig.get_bone_global_pose(pelvis)
	hips.origin += rig.global_basis.inverse() * Vector3(.13 * swing, -.69 * fold, -.16 * fold)
	rig.set_bone_global_pose(pelvis, hips)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .28 * fold)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .48 * fold - .17 * ward)
	turn_world(rig, "bip01 spine2", Vector3.UP, .65 * swing)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.14 * fold - .13 * ward)
	turn_world(rig, "bip01 head", Vector3.UP, -.39 * swing)
	turn_world(rig, "extrahead", Vector3.RIGHT, .11 * fold)
	fit_foot(rig, "l", targets[0])
	fit_foot(rig, "r", targets[1])
	var chest := joint_world(rig, "bip01 spine2")
	var head := joint_world(rig, "bip01 head")
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var hand := joint_world(rig, "bip01 %s hand" % side)
		var shelter := head + Vector3(sign_x * .61, .27 + .30 * sign_x, .37)
		var open := chest + Vector3(sign_x * (1.20 + .12 * fold), -.46 - .48 * fold, .55)
		var low := chest + Vector3(sign_x * .50, -1.19, .66)
		hand = hand.lerp(low, .82 * fold).lerp(shelter, ward).lerp(open, sweep)
		if side == "r":
			hand = hand.lerp(chest + Vector3(-.39, -.33, .61), touch)
		fit_arm(rig, side, hand)
		turn_world(rig, "bip01 %s hand" % side, Vector3.BACK, sign_x * (.22 * sweep - .36 * ward))


func pose_changeling(rig: Skeleton3D, phase: float, group: int) -> void:
	var tuck := 0.0
	var open := 0.0
	var pitch := 0.0
	var lean := 0.0
	match group:
		12:
			tuck = envelope(phase, .29, .62, .85, 1.0)
			open = envelope(phase, .02, .26, .44, .79)
			pitch = .33 * tuck
		23:
			tuck = 1.0 - smoothstep(.11, .59, phase)
			open = envelope(phase, .15, .47, .80, 1.0)
			lean = -.22 * sin(PI * phase)
		26:
			open = .79 * envelope(phase, .08, .37, .67, .96)
			lean = .23 * sin(TAU * phase) * sin(PI * phase)
		27:
			tuck = .64 * (1.0 - smoothstep(.13, .51, phase))
			open = envelope(phase, .21, .50, .72, 1.0)
			lean = .31 * sin(TAU * phase)
		28:
			tuck = .56 * smoothstep(.18, .85, phase)
			open = .63 * envelope(phase, .07, .30, .57, .91)
			pitch = .25 * tuck
	turn_world(rig, "bip01 pelvis", Vector3.BACK, lean)
	turn_world(rig, "bip01 pelvis", Vector3.RIGHT, -.27 * tuck + pitch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .33 * tuck - .16 * open)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.21 * tuck + .15 * pitch)
	var chest := joint_world(rig, "bip01 spine2")
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var wing := "bone_wingleft" if side == "l" else "bone_wingright"
		var flap := sin(TAU * phase * 2.3 + sign_x * .15)
		turn_world(rig, wing, Vector3.UP, sign_x * (.39 * open - .42 * tuck + .23 * flap))
		turn_world(rig, wing, Vector3.BACK, sign_x * (.30 * open - .29 * tuck - .18 * flap))
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.66 * tuck + .20 * open)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, 1.03 * tuck)
		var hand := joint_world(rig, "bip01 %s hand" % side)
		var wide := chest + Vector3(sign_x * .45, .04 + sign_x * lean, .12)
		var folded := chest + Vector3(sign_x * .13, -.22, .29)
		fit_arm(rig, side, hand.lerp(folded, tuck).lerp(wide, open))


func set_hover(clip: Animation, rig: Skeleton3D, group: int) -> void:
	var rig_path := clip.track_get_path(0).get_concatenated_names()
	var track := clip.find_track(NodePath("%s:%s" % [rig_path, RootJoint]), Animation.TYPE_POSITION_3D)
	assert(track >= 0)
	var parent := rig.get_bone_parent(rig.find_bone(RootJoint))
	var parent_frame := rig.global_basis * rig.get_bone_global_pose(parent).basis
	var up := parent_frame.inverse() * Vector3.UP
	for key in clip.track_get_key_count(track):
		var phase := clip.track_get_key_time(track, key) / clip.length
		var height := .22 + .11 * sin(TAU * phase)
		if group == 23:
			height = lerpf(.06, .42, smoothstep(.08, .67, phase))
		elif group == 12:
			height = .31 - .23 * smoothstep(.38, .98, phase)
		var position: Vector3 = clip.track_get_key_value(track, key)
		clip.track_set_key_value(track, key, position + up * height)
