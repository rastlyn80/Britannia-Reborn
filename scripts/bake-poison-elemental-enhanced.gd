# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/poison-elemental-dread-spider/"
const Clips := {23: "PoisonElementalCrouchedRise", 28: "PoisonElementalRaisedKneeGuard"}
const Lengths := {23: 1.22, 28: .64}
const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const PoisonJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]


func run() -> void:
	var row := Registry.entry(162)
	for treatment: String in Profile.registered_assets(row):
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
		for group: int in Clips:
			var motion := fit_grounded(player, rig, skins, Lengths[group], "bip01", PoisonJoints, pose_poison.bind(group), .005)
			assert(library.add_animation(Clips[group], motion) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Destination + "162-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("POISON ELEMENTAL ", treatment, ": two fitted motions with retained source keys")
	quit()


func pose_poison(rig: Skeleton3D, phase: float, group: int) -> void:
	var rise := group == 23
	var crouch := 1.0 - smoothstep(.06, .58, phase) if rise else .24 * smoothstep(.06, .56, phase)
	var spread := smoothstep(.13, .46, phase) * (1.0 - smoothstep(.67, 1.0, phase)) if rise else 0.0
	var guard := smoothstep(.08, .76, phase) if not rise else 0.0
	var ankles := {}
	var wrists := {}
	for side: String in ["l", "r"]:
		var ankle := rig.get_bone_global_pose(rig.find_bone("bip01 %s foot" % side))
		var sign_side := 1.0 if side == "l" else -1.0
		var step := Vector3(.07, .26, .18) * guard if side == "r" else Vector3.ZERO
		ankle.origin += rig.global_basis.inverse() * (Vector3(sign_side * .115, 0, .11) * crouch + step)
		ankles[side] = ankle
		wrists[side] = joint_world(rig, "bip01 %s hand" % side)
	var root_joint := rig.find_bone("bip01")
	var hips := rig.get_bone_global_pose(root_joint)
	hips.origin += rig.global_basis.inverse() * Vector3(.055 * guard, -.49 * crouch, -.21 * crouch - .095 * guard)
	rig.set_bone_global_pose(root_joint, hips)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 pelvis", Vector3.UP, -.16 * guard)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .64 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .36 * crouch)
	turn_world(rig, "bip01 spine2", Vector3.FORWARD, -.10 * spread + .17 * guard)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.19 * crouch)
	turn_world(rig, "bip01 head", Vector3.UP, .12 * spread + .24 * guard)
	var torso := joint_world(rig, "bip01 spine2")
	for side: String in ["l", "r"]:
		fit_foot(rig, side, ankles[side])
		var sign_side := 1.0 if side == "l" else -1.0
		var target: Vector3 = wrists[side]
		target = target.lerp(torso + Vector3(sign_side * .37, -.41, .31), crouch)
		target = target.lerp(torso + Vector3(sign_side * .85, .28 + .075 * sign_side, .07), spread)
		target = target.lerp(torso + Vector3(sign_side * .47, -.31 + .18 * sign_side, .48), guard)
		fit_arm(rig, side, target)
		turn_world(rig, "bip01 %s hand" % side, Vector3.BACK, sign_side * (.20 * spread - .27 * guard))
