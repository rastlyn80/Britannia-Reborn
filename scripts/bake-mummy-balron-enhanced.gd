# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-daemon-wyvern-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/mummy-daemon-elder/"
const MummyClips := {4: "MummyOverheadRecoil", 23: "MummyCrouchedRise", 28: "MummyRaisedArmsAlert"}
const MummyLengths := {4: .96, 23: 1.14, 28: .76}
const MummyJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]
const BalronClips := {23: "BalronWingCocoonRise", 26: "BalronWingWatch", 27: "BalronWingbeatRecoil", 28: "BalronWideThreat"}
const BalronLengths := {23: 1.32, 26: 1.16, 27: 1.21, 28: 1.13}
const BalronJoints := ["bip01 l hand", "bip01 r hand", "daemon l wing02", "daemon r wing02", "daemon l wing03", "daemon r wing03"]
const WingChain := [" mainwing01", " mainwing02", " wing01", " wing02", " wing03"]
const FoldDirections := [Vector3(.53, .47, -.18), Vector3(.12, .55, .86),
	Vector3(-.12, -.83, .60), Vector3(-.10, -.38, -.89)]


func run() -> void:
	bake_identity(154, MummyClips, MummyLengths, MummyJoints, pose_mummy)
	bake_identity(40, BalronClips, BalronLengths, DaemonJoints + BalronJoints, pose_balron)
	quit()


func bake_identity(body: int, clips: Dictionary, lengths: Dictionary, joints: Array, pose: Callable) -> void:
	var row := Registry.entry(body)
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_child("Body", true, false) as MeshInstance3D
		var skins: Array[Dictionary] = [Ground.skin_points(mesh, rig)]
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		for group: int in clips:
			var motion := fit_grounded(player, rig, skins, lengths[group], "bip01", joints, pose.bind(group), .007)
			assert(library.add_animation(clips[group], motion) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Destination + "%d-%s.scn" % [body, treatment], ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("MUMMY AND BALRON ", body, "/", treatment, ": ", clips.size(), " fitted motions with retained source keys")


func pose_mummy(rig: Skeleton3D, phase: float, group: int) -> void:
	var crouch := 0.0
	var arms := 0.0
	var guard := 0.0
	var raised_foot := 0.0
	match group:
		4:
			arms = envelope(phase, .02, .35, .46, .67)
			crouch = .43 * (1.0 - smoothstep(.02, .24, phase)) + .68 * envelope(phase, .40, .69, .84, 1.0)
			raised_foot = .14 * envelope(phase, .22, .53, .82, 1.0)
		23:
			crouch = 1.0 - smoothstep(.19, .91, phase)
		28:
			guard = smoothstep(.10, .72, phase)
			crouch = .25 * guard
			raised_foot = .12 * guard
	var ankles := {}
	var wrists := {}
	for side: String in ["l", "r"]:
		var ankle := rig.get_bone_global_pose(rig.find_bone("bip01 %s foot" % side))
		var sign_side := 1.0 if side == "l" else -1.0
		var recoil := Vector3(.03, raised_foot, -.11 * (arms + guard)) if side == "r" else Vector3.ZERO
		ankle.origin += rig.global_basis.inverse() * (Vector3(sign_side * .12, 0, .055) * crouch + recoil)
		ankles[side] = ankle
		wrists[side] = joint_world(rig, "bip01 %s hand" % side)
	var hips := rig.find_bone("bip01")
	var placement := rig.get_bone_global_pose(hips)
	placement.origin += rig.global_basis.inverse() * Vector3(-.06 * guard, -.58 * crouch, -.23 * crouch)
	rig.set_bone_global_pose(hips, placement)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .54 * crouch - .21 * arms)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .43 * crouch - .13 * arms)
	turn_world(rig, "bip01 spine2", Vector3.UP, .23 * arms + .16 * guard)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.22 * crouch - .17 * guard)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .20 * crouch)
	var torso := joint_world(rig, "bip01 spine2")
	for side: String in ["l", "r"]:
		fit_foot(rig, side, ankles[side])
		var sign_side := 1.0 if side == "l" else -1.0
		var hand: Vector3 = wrists[side]
		hand = hand.lerp(torso + Vector3(sign_side * .39, -.57, .40), crouch)
		hand = hand.lerp(torso + Vector3(sign_side * .68, .94 - .22 * sign_side, .14), arms)
		hand = hand.lerp(torso + Vector3(sign_side * .36, .26 + .13 * sign_side, .75), guard)
		fit_arm(rig, side, hand)
		turn_world(rig, "bip01 %s hand" % side, Vector3.BACK, .24 * sign_side * guard)


func pose_balron(rig: Skeleton3D, phase: float, group: int) -> void:
	var fold := 0.0
	var spread := 0.0
	var dip := 0.0
	var guard := 0.0
	var glance := 0.0
	match group:
		23:
			fold = 1.0 - smoothstep(.25, .60, phase)
			spread = smoothstep(.30, .65, phase)
			guard = .62 * envelope(phase, .30, .59, .78, 1.0)
		26:
			glance = .18 * sin(TAU * phase) * sin(PI * phase)
			dip = .20 * sin(TAU * phase)
		27:
			dip = .55 * envelope(phase, .03, .22, .33, .50)
			spread = .92 * envelope(phase, .23, .51, .69, 1.0)
			guard = .76 * envelope(phase, .07, .29, .45, .71)
		28:
			dip = .31 * envelope(phase, .02, .27, .45, .60)
			spread = .65 * envelope(phase, .26, .55, .68, 1.0)
			guard = .48 * envelope(phase, .18, .52, .72, 1.0)
	turn_world(rig, "bip01", Vector3.RIGHT, .27 * fold + .16 * dip)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .38 * fold - .12 * spread)
	turn_world(rig, "bip01 spine2", Vector3.UP, glance - .20 * guard)
	turn_world(rig, "bip01 head", Vector3.UP, .74 * glance)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .32 * fold - .18 * guard)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, .42 * fold + .18 * dip)
	turn_world(rig, "bip01 tail1", Vector3.UP, .43 * glance - .14 * spread)
	turn_world(rig, "bip01 tail2", Vector3.UP, .55 * glance)
	for side: String in ["l", "r"]:
		var sign_side := 1.0 if side == "l" else -1.0
		var limb := "bip01 " + side
		var wing := "daemon " + side
		turn_world(rig, limb + " thigh", Vector3.RIGHT, -.68 * fold - .16 * guard)
		turn_world(rig, limb + " calf", Vector3.RIGHT, .64 * fold + .20 * guard)
		turn_world(rig, limb + " foot", Vector3.RIGHT, -.26 * fold)
		turn_world(rig, limb + " upperarm", Vector3.RIGHT, -.56 * fold - .76 * guard)
		turn_world(rig, limb + " forearm", Vector3.RIGHT, -.41 * fold - .53 * guard)
		turn_world(rig, limb + " hand", Vector3.BACK, .31 * sign_side * guard)
		turn_world(rig, wing + " mainwing01", Vector3.BACK, sign_side * (-.48 * spread + .31 * dip))
		turn_world(rig, wing + " mainwing01", Vector3.UP, -sign_side * .45 * spread)
		turn_world(rig, wing + " mainwing02", Vector3.UP, -sign_side * .33 * spread)
		turn_world(rig, wing + " wing01", Vector3.RIGHT, .30 * dip)
		turn_world(rig, wing + " wing02", Vector3.UP, -sign_side * .16 * spread)
		turn_world(rig, wing + " wing03", Vector3.BACK, sign_side * .21 * dip)
		if fold > 0.0:
			wrap_wing(rig, wing, sign_side, fold)


func wrap_wing(rig: Skeleton3D, wing: String, side: float, amount: float) -> void:
	# Lift the leading edge, bring the membrane down around the shoulder, then
	# turn the tip back towards the flank. Each link retains its authored length.
	for index in FoldDirections.size():
		var bone := rig.find_bone(wing + WingChain[index])
		var child := rig.find_bone(wing + WingChain[index + 1])
		var pose := rig.get_bone_global_pose(bone)
		var along := (rig.get_bone_global_pose(child).origin - pose.origin).normalized()
		var aim: Vector3 = FoldDirections[index]
		aim.x *= side
		aim = (rig.global_basis.inverse() * aim).normalized()
		pose.basis = Basis(Quaternion.IDENTITY.slerp(Quaternion(along, aim), amount)) * pose.basis
		rig.set_bone_global_pose(bone, pose)
		rig.force_update_all_bone_transforms()
