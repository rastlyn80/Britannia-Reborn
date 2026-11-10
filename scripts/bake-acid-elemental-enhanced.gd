# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/bone-knight-acid-elemental/"
const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Clips := {23: "AcidElementalCondense", 28: "AcidElementalSpatterGuard"}
const Lengths := {23: 1.17, 28: .71}
const AcidJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck",
	"bip01 head", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand"]


func run() -> void:
	var row := Registry.entry(158)
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
			var motion := fit_grounded(player, rig, skins, Lengths[group], "__root", AcidJoints, pose_acid.bind(group), .005)
			if group == 23:
				install_growth_track(motion, player, rig)
			assert(library.add_animation(Clips[group], motion) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var packed := PackedScene.new()
		assert(packed.pack(model) == OK)
		assert(ResourceSaver.save(packed, Destination + "158-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("ACID ELEMENTAL ", treatment, ": two fitted motions on the original rig")
	quit()


func growth_scale(rig: Skeleton3D, phase: float) -> Vector3:
	var height := lerpf(.044, 1.0, smoothstep(.03, .69, phase))
	var width := lerpf(.062, 1.0, smoothstep(.19, .76, phase))
	var root_basis := rig.global_basis * rig.get_bone_global_rest(rig.find_bone("__root")).basis
	var up := (root_basis.inverse() * Vector3.UP).normalized().abs()
	return Vector3.ONE * width + up * (height - width)


func install_growth_track(motion: Animation, player: AnimationPlayer, rig: Skeleton3D) -> void:
	var path := NodePath("%s:__root" % player.get_node(player.root_node).get_path_to(rig))
	var track := motion.find_track(path, Animation.TYPE_SCALE_3D)
	if track < 0:
		track = motion.add_track(Animation.TYPE_SCALE_3D)
		motion.track_set_path(track, path)
	else:
		motion.track_remove_key(track, 0)
	for index in 81:
		var phase := index / 80.0
		motion.scale_track_insert_key(track, motion.length * phase, growth_scale(rig, phase))


func pose_acid(rig: Skeleton3D, phase: float, group: int) -> void:
	var rise := group == 23
	var tucked := 1.0 - smoothstep(.23, .75, phase) if rise else 0.0
	var reach := .46 * envelope(phase, .42, .63, .79, .99) if rise else envelope(phase, .07, .48, .73, .99)
	var shift := .32 * sin(TAU * phase) * reach
	turn_world(rig, "bip01 pelvis", Vector3.RIGHT, .30 * tucked)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .42 * tucked - .12 * reach)
	turn_world(rig, "bip01 spine1", Vector3.UP, shift)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, .37 * tucked + .17 * reach)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.35 * tucked)
	turn_world(rig, "bip01 head", Vector3.UP, -.54 * shift)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign * (.76 * reach - .26 * tucked))
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.45 * reach + .37 * tucked)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.57 * reach - .86 * tucked)
		turn_world(rig, "bip01 %s hand" % side, Vector3.UP, sign * .34 * reach)
	if rise:
		rig.set_bone_pose_scale(rig.find_bone("__root"), growth_scale(rig, phase))
		rig.force_update_all_bone_transforms()
