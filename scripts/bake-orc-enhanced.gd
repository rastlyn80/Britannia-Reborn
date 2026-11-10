# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const Output := "res://../work/creatures/native-form-audit/enhanced-source-gaps/amou/orc-%s.scn"
const Actions := {23: "OrcRise", 28: "OrcAlert"}
const Joints := [
	"bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 spine3", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 r upperarm", "bip01 r forearm",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot",
]

# Front and profile registrations are the pose guides. Each row holds
# drop, torso lean, torso turn and right/left wrist offsets from the hips.
const Rise := [
	[.53, 1.19, 0.00, Vector3(-.30, .08, .57), Vector3(.28, .10, .57)],
	[.51, 1.13, 0.00, Vector3(-.30, .10, .58), Vector3(.29, .12, .57)],
	[.43, .99, -.02, Vector3(-.32, .13, .57), Vector3(.30, .15, .55)],
	[.34, .74, -.04, Vector3(-.36, .12, .50), Vector3(.35, .15, .49)],
	[.22, .46, -.05, Vector3(-.42, .08, .38), Vector3(.40, .12, .41)],
	[.12, .21, -.04, Vector3(-.46, .02, .22), Vector3(.46, .04, .29)],
	[.04, .06, -.02, Vector3(-.49, .01, .10), Vector3(.47, .02, .21)],
	[.00, .00, .00, Vector3(-.48, .02, .06), Vector3(.45, .04, .17)],
]
const Alert := [
	[.00, .00, .00, Vector3(-.48, .02, .06), Vector3(.45, .04, .17)],
	[.06, .15, .08, Vector3(-.56, .26, .30), Vector3(.43, -.08, .22)],
	[.11, .23, .17, Vector3(-.57, .40, .43), Vector3(.43, -.17, .32)],
	[.15, .27, .19, Vector3(-.55, .47, .47), Vector3(.42, -.12, .44)],
	[.13, .22, .23, Vector3(-.50, .49, .44), Vector3(.42, .02, .53)],
	[.10, .16, .26, Vector3(-.46, .48, .38), Vector3(.42, .15, .60)],
	[.10, .15, .27, Vector3(-.43, .44, .35), Vector3(.42, .23, .63)],
	[.11, .15, .28, Vector3(-.42, .42, .33), Vector3(.41, .25, .63)],
]

func run() -> void:
	var row := Registry.entry(17)
	assert(row.kind == "orcs_orc_fidgets")
	for treatment: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
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
		for group: int in Actions:
			var clip := fit_grounded(player, rig, skins, .70, "bip01", Joints, pose_orc.bind(group), .006)
			assert(library.add_animation(Actions[group], clip) == OK)
		Exact.check_earlier_keys(player, source)
		player.stop()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Output % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("ORC ENHANCED CANDIDATE: ", treatment, " rise and alert with original keys preserved")
	quit()

func pose_orc(rig: Skeleton3D, phase: float, group: int) -> void:
	var poses := Rise if group == 23 else Alert
	var time := phase * (poses.size() - 1)
	var index := mini(floori(time), poses.size() - 2)
	var a: Array = poses[index]
	var b: Array = poses[index + 1]
	var weight := smoothstep(0.0, 1.0, time - index)
	var drop := lerpf(a[0], b[0], weight)
	var lean := lerpf(a[1], b[1], weight)
	var yaw := lerpf(a[2], b[2], weight)
	var targets := {}
	for side: String in ["l", "r"]:
		var sign_side := 1.0 if side == "l" else -1.0
		var foot := rig.get_bone_global_pose(rig.find_bone("bip01 %s foot" % side))
		var toe := rig.get_bone_global_pose(rig.find_bone("bip01 %s toe0" % side)).origin
		var forward := rig.global_basis.inverse() * Vector3(sign_side * .20, -.49, .85)
		foot.basis = Basis(Quaternion((toe - foot.origin).normalized(), forward.normalized())) * foot.basis
		var ankle := Vector3(sign_side * .26, .145, sign_side * .085)
		if side == "r" and group == 28:
			var step := smoothstep(.16, .58, phase)
			var lift := .085 * sin(PI * step)
			ankle += Vector3(-.15 * step, lift, .23 * step)
		foot.origin = rig.to_local(ankle)
		targets[side] = foot
	var root_bone := rig.find_bone("bip01")
	var hips := rig.get_bone_global_pose(root_bone)
	hips.origin += rig.global_basis.inverse() * Vector3(0, -drop, -.25 * drop)
	rig.set_bone_global_pose(root_bone, hips)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 pelvis", Vector3.UP, yaw * .45)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, lean * .53)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, lean * .28)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, lean * .21)
	turn_world(rig, "bip01 spine3", Vector3.UP, yaw * .65)
	turn_world(rig, "bip01 head", Vector3.RIGHT, lean * -.16)
	for side: String in ["l", "r"]:
		fit_foot(rig, side, targets[side])
	var pelvis := joint_world(rig, "bip01 pelvis")
	fit_arm(rig, "r", pelvis + (a[3] as Vector3).lerp(b[3], weight))
	fit_arm(rig, "l", pelvis + (a[4] as Vector3).lerp(b[4], weight))

func fit_foot(rig: Skeleton3D, side: String, target: Transform3D) -> void:
	var thigh := rig.find_bone("bip01 %s thigh" % side)
	var calf := rig.find_bone("bip01 %s calf" % side)
	var foot := rig.find_bone("bip01 %s foot" % side)
	var hip := rig.get_bone_global_pose(thigh).origin
	var original_knee := rig.get_bone_global_pose(calf).origin
	var upper := original_knee.distance_to(hip)
	var lower := rig.get_bone_global_pose(foot).origin.distance_to(original_knee)
	var axis := (target.origin - hip).normalized()
	var span := clampf(hip.distance_to(target.origin), absf(upper - lower) + .001, upper + lower - .001)
	var along := (upper * upper - lower * lower + span * span) / (2.0 * span)
	var side_offset := .22 if side == "l" else -.22
	var bend := (rig.global_basis.inverse() * Vector3(side_offset, .0, 1.0)).slide(axis).normalized()
	var knee := hip + axis * along + bend * sqrt(maxf(0.0, upper * upper - along * along))
	Arms.aim(rig, thigh, calf, knee)
	rig.force_update_all_bone_transforms()
	Arms.aim(rig, calf, foot, target.origin)
	rig.force_update_all_bone_transforms()
	target.origin = rig.get_bone_global_pose(foot).origin
	rig.set_bone_global_pose(foot, target)
	rig.force_update_all_bone_transforms()
