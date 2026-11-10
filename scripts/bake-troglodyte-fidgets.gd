# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-troglodyte-gaits.gd"

const FIDGETS := {26: "TroglodyteSettleFidget", 27: "TroglodyteRaisedFidget"}
# Source ordinals 1, 3, 5, 7, 9 and 10, cross-checked in directions 2 and 3.
# Depth, torso turn and left/right wrist goals relative to the pelvis.
const REFERENCE := {
	26: [
		[.18, -.27, Vector3(.93, -.63, 1.22), Vector3(-1.02, .55, .11)],
		[.06, -.36, Vector3(1.18, -.40, 1.47), Vector3(-1.20, .70, -.44)],
		[.07, -.29, Vector3(.87, .12, 1.06), Vector3(-1.15, .64, -.25)],
		[.15, -.10, Vector3(1.12, -.73, 1.22), Vector3(-.92, -.09, 1.06)],
		[.68, .07, Vector3(.80, -.28, 1.27), Vector3(-.76, -.48, .98)],
		[.58, .05, Vector3(.92, -.62, .89), Vector3(-.94, -.62, .74)],
	],
	27: [
		[.66, .04, Vector3(.96, -.81, .87), Vector3(-.96, -.80, .82)],
		[.29, -.26, Vector3(1.13, -.28, .99), Vector3(-1.08, .80, .89)],
		[-.14, -.47, Vector3(1.49, .95, 1.27), Vector3(-1.51, .97, -.44)],
		[-.21, -.58, Vector3(1.47, 1.29, 1.20), Vector3(-1.61, 1.11, -.48)],
		[-.10, -.30, Vector3(1.12, .49, 1.14), Vector3(-1.35, .96, -.02)],
		[.03, -.18, Vector3(.91, .07, 1.05), Vector3(-1.05, .53, .43)],
	],
}
const ORDINALS := [0.0, 2.0, 4.0, 6.0, 8.0, 9.0]

func run() -> void:
	var row := Registry.entry(267)
	assert(row.has("troglodyte_gaits"))
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.deterministic = true
		var skins: Array[Dictionary] = []
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin != null:
				skins.append(Ground.skin_points(mesh, rig))
		for group: int in FIDGETS:
			var clip := fit_grounded(player, rig, skins, .9, "bip01", JOINTS, pose_fidget.bind(group), .006)
			assert(library.add_animation(FIDGETS[group], clip) == OK)
		Exact.check_earlier_keys(player, source)
		player.stop()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		var path := GAIT_OUTPUT.replace("-gaits-", "-fidgets-") % treatment
		assert(ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("TROGLODYTE FIDGETS: ", treatment, " / groups 26 and 27")
	quit()

func pose_fidget(rig: Skeleton3D, phase: float, group: int) -> void:
	var poses: Array = REFERENCE[group]
	var ordinal := phase * ORDINALS[-1]
	var interval := mini(floori(ordinal / 2.0), ORDINALS.size() - 2)
	var mix := smoothstep(ORDINALS[interval], ORDINALS[interval + 1], ordinal)
	var first: Array = poses[interval]
	var next: Array = poses[interval + 1]
	var depth := lerpf(first[0], next[0], mix)
	var yaw := lerpf(first[1], next[1], mix)
	var feet := foot_poses(rig)
	var root_joint := rig.find_bone("bip01")
	var root_pose := rig.get_bone_global_pose(root_joint)
	root_pose.origin += rig.global_basis.inverse() * Vector3(0, -.56 * depth, -.16 * depth)
	rig.set_bone_global_pose(root_joint, root_pose)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .39 * depth)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .28 * depth)
	turn_world(rig, "bip01 spine2", Vector3.UP, yaw)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.22 * depth)
	var hips := joint_world(rig, "bip01 pelvis")
	fit_arm(rig, "l", hips + (first[2] as Vector3).lerp(next[2], mix))
	fit_arm(rig, "r", hips + (first[3] as Vector3).lerp(next[3], mix))
	for side: String in feet:
		aim_foot(rig, side, feet[side])
