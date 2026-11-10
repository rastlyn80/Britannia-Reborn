# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/giant-toad-juka-warrior/"
const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const ToadClips := {25: "GiantToadQuietBreath", 26: "GiantToadTongueSnap"}
const JukaClips := {23: "JukaWarriorCrouchedRise", 28: "JukaWarriorGuardKick"}
const ToadLengths := {25: .92, 26: .90}
const JukaLengths := {23: 1.02, 28: .69}
const Tongue := ["bip01 ponytail1", "bip01 ponytail11", "bip01 ponytail12", "bip01 ponytail13"]
const ToadJoints := ["bip01 spine", "bip01 spine1", "bip01 neck", "bip01 head"] + Tongue
const JukaJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]


func run() -> void:
	bake_identity(80, ToadClips, ToadLengths, ToadJoints, pose_toad)
	bake_identity(764, JukaClips, JukaLengths, JukaJoints, pose_juka)
	quit()


func bake_identity(body: int, clips: Dictionary, lengths: Dictionary, joints: Array, pose: Callable) -> void:
	var row := Registry.entry(body)
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
		for group: int in clips:
			var motion := fit_grounded(player, rig, skins, lengths[group], "bip01", joints, pose.bind(group), .006)
			assert(library.add_animation(clips[group], motion) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Destination + "%d-%s.scn" % [body, treatment], ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("GIANT TOAD AND JUKA WARRIOR ", body, "/", treatment, ": ", clips.size(), " fitted motions with retained source keys")


func pose_toad(rig: Skeleton3D, phase: float, group: int) -> void:
	var tongue := smoothstep(.10, .27, phase) * (1.0 - smoothstep(.34, .55, phase)) if group == 26 else 0.0
	var swallow := smoothstep(.38, .53, phase) * (1.0 - smoothstep(.62, .82, phase)) if group == 26 else 0.0
	var breath := sin(TAU * phase) * (.017 if group == 25 else .012)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.024 * tongue + breath)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.057 * tongue - .028 * swallow)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.10 * tongue + .062 * swallow - .55 * breath)
	turn_world(rig, Tongue[0], Vector3.RIGHT, .10 * swallow + .022 * breath)
	if tongue <= 0.0:
		return
	var inverse := rig.global_basis.inverse()
	for index in Tongue.size() - 1:
		var bone := rig.find_bone(Tongue[index])
		var child := rig.find_bone(Tongue[index + 1])
		var pose := rig.get_bone_global_pose(bone)
		var along := (rig.get_bone_global_pose(child).origin - pose.origin).normalized()
		var direction := Vector3(0, -.24 + .095 * index, 1.0)
		var aim := (inverse * direction).normalized()
		pose.basis = Basis(Quaternion.IDENTITY.slerp(Quaternion(along, aim), tongue)) * pose.basis
		rig.set_bone_global_pose(bone, pose)
		rig.force_update_all_bone_transforms()


func pose_juka(rig: Skeleton3D, phase: float, group: int) -> void:
	var rise := group == 23
	var crouch := 1.0 - smoothstep(.10, .90, phase) if rise else .35 * smoothstep(.04, .55, phase)
	var guard := smoothstep(.06, .42, phase) if not rise else 0.0
	var kick := smoothstep(.38, .91, phase) if not rise else 0.0
	var ankles := {}
	var wrists := {}
	for side: String in ["l", "r"]:
		var sign_side := 1.0 if side == "l" else -1.0
		var ankle := rig.get_bone_global_pose(rig.find_bone("bip01 %s foot" % side))
		var kick_target := Vector3(.17, .30, .66) * kick if side == "l" else Vector3.ZERO
		ankle.origin += rig.global_basis.inverse() * (Vector3(sign_side * .095, 0, .11) * crouch + kick_target)
		ankles[side] = ankle
		wrists[side] = joint_world(rig, "bip01 %s hand" % side)
	var hips := rig.find_bone("bip01")
	var placement := rig.get_bone_global_pose(hips)
	placement.origin += rig.global_basis.inverse() * Vector3(-.115 * kick, -.58 * crouch, -.24 * crouch - .07 * kick)
	rig.set_bone_global_pose(hips, placement)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 pelvis", Vector3.UP, .18 * kick)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .45 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .34 * crouch)
	turn_world(rig, "bip01 spine2", Vector3.UP, .29 * guard - .23 * kick)
	turn_world(rig, "bip01 spine2", Vector3.FORWARD, .23 * kick)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.28 * crouch)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .19 * crouch + .17 * guard)
	var torso := joint_world(rig, "bip01 spine2")
	for side: String in ["l", "r"]:
		fit_foot(rig, side, ankles[side])
		var sign_side := 1.0 if side == "l" else -1.0
		var hand: Vector3 = wrists[side]
		hand = hand.lerp(torso + Vector3(sign_side * .30, -.38, .44), crouch)
		hand = hand.lerp(torso + Vector3(sign_side * .31, .22 - .12 * sign_side, .42), guard)
		fit_arm(rig, side, hand)
