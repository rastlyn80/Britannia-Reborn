# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const OUTPUT := "res://../work/creatures/native-form-audit/enhanced-source-gaps/troglodyte-enhanced-%s.scn"
const Legs := preload("res://Presentation/FootContact.gd")
const SOURCE_CLIPS := {4: "TroglodyteHighSweep", 23: "TroglodyteLowRecoil", 28: "TroglodyteOpenReach"}
const JOINTS := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 r upperarm", "bip01 r forearm",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]

# Each row follows one stored reference pose. Crouch and torso yaw come
# before the right and left wrist goals in metres relative to the pelvis.
const POSES := {
	4: [
		[.05, -.12, Vector3(-.91, 1.16, 1.30), Vector3(.83, .42, 1.11)],
		[-.67, -.25, Vector3(-.70, 2.75, .08), Vector3(.87, .84, 1.46)],
		[-.12, -.38, Vector3(-1.13, 1.30, .83), Vector3(.61, .56, 1.70)],
		[.65, .28, Vector3(-.78, -.06, 2.39), Vector3(1.11, .27, -.68)],
		[.54, .22, Vector3(-1.06, -.21, 1.70), Vector3(1.22, .06, -.28)],
		[.50, .14, Vector3(-1.17, -.59, .79), Vector3(1.00, -.11, .52)],
		[.38, .11, Vector3(-1.42, -.58, .70), Vector3(.89, -.08, .70)],
		[.32, .05, Vector3(-1.35, -.40, .74), Vector3(.78, -.06, .96)],
		[.25, -.02, Vector3(-1.21, -.26, .96), Vector3(.67, .02, 1.18)],
	],
	23: [
		[.75, .07, Vector3(-.83, -.34, 1.35), Vector3(.58, -.08, .83)],
		[.48, -.12, Vector3(-.84, .32, 1.96), Vector3(.69, -.20, .90)],
		[.19, -.04, Vector3(-1.12, -.47, 1.43), Vector3(.74, -.11, 1.08)],
		[.55, .05, Vector3(-1.16, -.55, .90), Vector3(.74, -.20, 1.05)],
		[.43, .19, Vector3(-1.11, -.33, 1.42), Vector3(.85, .20, 1.75)],
		[-.24, -.39, Vector3(-1.42, 1.01, -.32), Vector3(.57, .71, 1.84)],
		[.26, -.29, Vector3(-1.13, .76, -.18), Vector3(.73, .44, 1.69)],
		[.58, .10, Vector3(-.95, -.68, 1.72), Vector3(.77, -.32, 1.11)],
	],
	28: [
		[.56, -.06, Vector3(-1.31, -.56, .71), Vector3(.67, -.28, 1.00)],
		[.48, -.03, Vector3(-1.29, -.60, .84), Vector3(.70, -.28, 1.11)],
		[.28, -.10, Vector3(-1.37, -.54, 1.13), Vector3(.83, -.15, 1.24)],
		[.08, -.16, Vector3(-1.32, -.38, 1.45), Vector3(.97, .01, 1.35)],
		[.08, -.18, Vector3(-1.25, -.25, 1.66), Vector3(1.08, .17, 1.42)],
		[.06, -.22, Vector3(-1.26, -.06, 1.96), Vector3(1.24, .26, 1.61)],
		[.10, -.22, Vector3(-1.29, .08, 2.18), Vector3(1.31, .26, 1.76)],
	],
}

func run() -> void:
	var row := Registry.entry(267)
	assert(row.kind == "troglodyte")
	var layer: Dictionary = row.get("troglodyte_enhanced", {})
	var assets: Dictionary = layer.get("source_assets", row.assets)
	var hashes: Dictionary = layer.get("source_sha256", row.asset_sha256)
	var target_folder := ProjectSettings.globalize_path((OUTPUT % "original").get_base_dir())
	assert(DirAccess.make_dir_recursive_absolute(target_folder) == OK)
	for treatment: String in ["original", "rounded", "modern"]:
		var source: String = assets[treatment]
		assert(FileAccess.get_sha256(source) == hashes[treatment])
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
		for group: int in SOURCE_CLIPS:
			var poses: Array = POSES[group]
			var length := .10 * (poses.size() - 1)
			var clip := fit_grounded(player, rig, skins, length, "bip01", JOINTS, pose_source.bind(group), .006)
			assert(library.add_animation(SOURCE_CLIPS[group], clip) == OK)
		Exact.check_earlier_keys(player, source)
		player.stop()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, OUTPUT % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("TROGLODYTE ENHANCED TRIAL: ", treatment, ", three fits with retained source keys")
	quit()

func pose_source(rig: Skeleton3D, phase: float, group: int) -> void:
	var poses: Array = POSES[group]
	var offset := phase * (poses.size() - 1)
	var index := mini(floori(offset), poses.size() - 2)
	var a: Array = poses[index]
	var b: Array = poses[index + 1]
	var mix := smoothstep(0.0, 1.0, offset - index)
	var crouch := lerpf(a[0], b[0], mix)
	var yaw := lerpf(a[1], b[1], mix)
	turn_world(rig, "bip01 pelvis", Vector3.UP, yaw * .40)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, crouch * .41)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, crouch * .34)
	turn_world(rig, "bip01 spine2", Vector3.UP, yaw * .75)
	turn_world(rig, "bip01 head", Vector3.RIGHT, crouch * -.18)
	if group == 23:
		fit_low_stance(rig, crouch)
	else:
		for side: String in ["l", "r"]:
			var bias := 1.0 if side == "l" else .70
			turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.72 * crouch * bias)
			turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, 1.24 * crouch * bias)
			turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.52 * crouch * bias)
	var hips := joint_world(rig, "bip01 pelvis")
	fit_arm(rig, "r", hips + (a[2] as Vector3).lerp(b[2], mix))
	fit_arm(rig, "l", hips + (a[3] as Vector3).lerp(b[3], mix))

func fit_low_stance(rig: Skeleton3D, crouch: float) -> void:
	var depth := smoothstep(.12, .77, crouch)
	var ground_goals := {}
	for side: String in ["l", "r"]:
		var foot := rig.get_bone_global_pose(rig.find_bone("bip01 %s foot" % side))
		var offset := Vector3(0, 0, -.16 if side == "l" else .50) * depth
		foot.origin += rig.global_basis.inverse() * offset
		ground_goals[side] = foot
	var root_index := rig.find_bone("bip01")
	var body := rig.get_bone_global_pose(root_index)
	body.origin += rig.global_basis.inverse() * Vector3(0, -.87 * depth, -.28 * depth)
	rig.set_bone_global_pose(root_index, body)
	rig.force_update_all_bone_transforms()
	for side: String in ["l", "r"]:
		var thigh := rig.find_bone("bip01 %s thigh" % side)
		var calf := rig.find_bone("bip01 %s calf" % side)
		var foot := rig.find_bone("bip01 %s foot" % side)
		var goal: Transform3D = ground_goals[side]
		var knee := Legs.knee_target(rig.get_bone_global_pose(thigh).origin,
			rig.get_bone_global_pose(calf).origin, rig.get_bone_global_pose(foot).origin, goal.origin)
		Arms.aim(rig, thigh, calf, knee)
		rig.force_update_all_bone_transforms()
		Arms.aim(rig, calf, foot, goal.origin)
		rig.force_update_all_bone_transforms()
		goal.origin = rig.get_bone_global_pose(foot).origin
		rig.set_bone_global_pose(foot, goal)
		rig.force_update_all_bone_transforms()
