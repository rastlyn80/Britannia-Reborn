# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/giant-rat-vampire-bat/"
const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const GiantRatClips := {4: "GiantRatForwardBite", 15: "GiantRatNoseRecoil", 23: "GiantRatTailUnfurl",
	25: "GiantRatForage", 26: "GiantRatScentCheck", 27: "GiantRatTailSweep", 28: "GiantRatNoseAlert"}
const Lengths := {4: .74, 15: .50, 23: .88, 25: .83, 26: .76, 27: .54, 28: .63}
const RatJoints := ["bip01", "bip01 spine", "bip01 spine1", "bip01 neck", "bip01 head", "bip01 ponytail1",
	"bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3", "bip01 l upperarm", "bip01 l forearm",
	"bip01 r upperarm", "bip01 r forearm", "bip01 l foot", "bip01 r foot"]


func run() -> void:
	var row := Registry.entry(215)
	for treatment: String in Profile.registered_assets(row):
		bake_rat(treatment, row)
	quit()


func bake_rat(treatment: String, row: Dictionary) -> void:
	var source := Registry.asset_path(row, treatment)
	assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skins: Array[Dictionary] = [Ground.skin_points(mesh, rig)]
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	for group: int in GiantRatClips:
		var motion := fit_grounded(player, rig, skins, Lengths[group], "bip01", RatJoints, pose_rat.bind(group), .004)
		assert(library.add_animation(GiantRatClips[group], motion) == OK)
	verify_base_clips(player, source)
	player.stop()
	rig.reset_bone_poses()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed, Stage + "215-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("GIANT RAT ", treatment, ": seven fitted motions")


func pose_rat(rig: Skeleton3D, phase: float, group: int) -> void:
	var drive := 0.0
	var curl := 0.0
	var lift := 0.0
	var sniff := 0.0
	var bite := 0.0
	var flinch := 0.0
	match group:
		4:
			drive = envelope(phase, .15, .36, .49, .89)
			bite = .62 * drive
			curl = .32 * envelope(phase, .01, .18, .34, .57)
		15:
			flinch = envelope(phase, .02, .23, .45, .82)
			curl = .30 * flinch
		23:
			curl = 1.0 - smoothstep(.02, .95, phase)
			lift = .32 * envelope(phase, .07, .33, .55, .83)
		25:
			sniff = .18 * sin(TAU * 2.0 * phase) * sin(PI * phase)
			drive = .33 * envelope(phase, .11, .33, .69, .98)
			bite = .26 * absf(sniff)
		26:
			lift = .22 * envelope(phase, .11, .47, .64, .94)
			sniff = .22 * sin(TAU * 1.5 * phase) * sin(PI * phase)
		27:
			curl = -.43 * sin(TAU * phase) * sin(PI * phase)
			sniff = .08 * sin(TAU * phase)
		28:
			lift = .48 * envelope(phase, .12, .43, .65, .96)
			curl = .16 * sin(TAU * phase) * sin(PI * phase)
	var hip := rig.find_bone("bip01")
	var hip_pose := rig.get_bone_global_pose(hip)
	hip_pose.origin += rig.global_basis.inverse() * Vector3.BACK * (.15 * drive - .075 * flinch)
	rig.set_bone_global_pose(hip, hip_pose)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .12 * drive - .20 * lift + .16 * flinch)
	turn_world(rig, "bip01 spine1", Vector3.BACK, -.16 * flinch)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .29 * drive - .43 * lift + .14 * sniff)
	turn_world(rig, "bip01 head", Vector3.UP, .40 * sniff + .20 * flinch)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.25 * lift + .29 * sniff)
	turn_world(rig, "bip01 ponytail1", Vector3.RIGHT, .42 * bite)
	turn_world(rig, "bip01 tail", Vector3.UP, .88 * curl)
	turn_world(rig, "bip01 tail1", Vector3.UP, .85 * curl)
	turn_world(rig, "bip01 tail2", Vector3.UP, .74 * curl - .15 * drive)
	turn_world(rig, "bip01 tail3", Vector3.UP, .69 * curl)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, .37 * lift + .19 * flinch)
	for side: String in ["l", "r"]:
		var amount := .72 if side == "l" else 1.0
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.39 * drive * amount + .29 * lift)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, .28 * drive - .16 * lift)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.16 * flinch)

