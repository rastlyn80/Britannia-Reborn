# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-troglodyte-enhanced.gd"

const Folder := "res://../work/creatures/native-form-audit/enhanced-source-gaps/common-forms-enhanced/troglodyte-variants/"
const Recover := {
	5: "TroglodyteCrossingStrike", 10: "TroglodyteArmRecoil",
	11: "TroglodyteLoweredReach", 15: "TroglodyteBracedRecoil",
}
const Motions := {5: .71, 10: .61, 11: 1.08, 15: .69}


func run() -> void:
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Folder)) == OK)
	for treatment: String in ["original", "rounded", "modern"]:
		var filename := "267-%s.scn" % treatment
		var source := "res://local-art/creatures/enhanced-creature-actions/" + filename
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var skins: Array[Dictionary] = []
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin != null:
				skins.append(Ground.skin_points(mesh, rig))
		var clips := SOURCE_CLIPS.merged(Recover)
		for group: int in clips:
			var name: String = clips[group]
			if library.has_animation(name):
				continue
			var length: float = Motions.get(group, .10 * (POSES.get(group, [0, 0]).size() - 1))
			var pose := pose_source if group in SOURCE_CLIPS else recover_pose
			assert(library.add_animation(name, fit_grounded(player, rig, skins, length, "bip01",
				JOINTS, pose.bind(group), .005)) == OK)
		Exact.check_earlier_keys(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, Folder + filename, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("TROGLODYTE COMBAT FIT ", treatment, " ", clips.values())
	quit()


func recover_pose(rig: Skeleton3D, phase: float, group: int) -> void:
	var up := smoothstep(.03, .30, phase) * (1.0 - smoothstep(.51, .91, phase))
	var out := smoothstep(.22, .51, phase) * (1.0 - smoothstep(.64, 1.0, phase))
	var crouch := .45 * out
	var yaw := .26 * up - .36 * out
	var arm := Vector3(-.85, .72 + .68 * up, .67 + .80 * out)
	var off := Vector3(.68 + .20 * up, .10 + .18 * out, .89)
	match group:
		10:
			crouch = .66 * (1.0 - up)
			yaw = -.21 * up
			arm = Vector3(-.98, .10 + .76 * up, 1.05 + .49 * up)
		11:
			crouch = .69 * out
			yaw = .14 * sin(TAU * phase) * out
			arm = Vector3(-.95, .28 - .69 * out, .78 + 1.11 * out)
			off = Vector3(.68, .12 - .45 * out, .82 + .66 * out)
		15:
			crouch = .58 * up
			yaw = -.33 * out
			arm = Vector3(-.80, .30 + .47 * up, .88 + .63 * out)
	turn_world(rig, "bip01 pelvis", Vector3.UP, .40 * yaw)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .43 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .39 * crouch)
	turn_world(rig, "bip01 spine2", Vector3.UP, .64 * yaw)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.27 * crouch)
	fit_low_stance(rig, crouch)
	var hips := joint_world(rig, "bip01 pelvis")
	fit_arm(rig, "r", hips + arm)
	fit_arm(rig, "l", hips + off)
