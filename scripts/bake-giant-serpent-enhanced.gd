# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Base := "res://local-art/creatures/enhanced-creature-actions/21-"
const PoseJoints := ["bip01", "bip01 pelvis", "bip01 spine", "bip01 tail", "bip01 tail1", "bip01 tail2",
	"bip01 tail3", "bip01 tail4", "bip01 neck", "bip01 neck1", "bip01 neck2", "bip01 neck3",
	"bip01 neck4", "bip01 head", "bip01 ponytail1"]
const Fits := {
	0: ["SerpentCombatSlither", .9], 25: ["SerpentQuietIdle", 1.2],
}
const ArchiveCandidate := {
	1: "Idle", 2: "Death2", 3: "Death", 4: "SerpentUncoilStrike", 10: "Hit", 11: "Pillage",
	15: "LowNeckRecoil", 22: "Walk", 23: "SerpentSurface", 24: "Run", 26: "SerpentLowWatch",
	27: "SerpentRaisedCoil", 28: "SerpentCoilAlert",
}
var walk_poses: Array
var quiet_pose: Array[Quaternion]


func run() -> void:
	var folder := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--study="):
			folder = argument.trim_prefix("--study=")
	if folder.is_empty() or not DirAccess.dir_exists_absolute(folder):
		printerr("Provide an existing private output directory using --study.")
		quit(1)
		return
	for style: String in ["original", "rounded", "modern"]:
		var source := Base + style + ".scn"
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var space := model.find_child("SourceSpace", true, false) as Node3D
		var source_space := space.transform
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		for clip: String in ArchiveCandidate.values():
			assert(player.has_animation(clip), clip)
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		collect_base_poses(player, rig)
		var skins: Array[Dictionary] = [Ground.skin_points(mesh, rig)]
		for group: int in Fits:
			var clip := fit_grounded(player, rig, skins, Fits[group][1], "bip01", PoseJoints,
				pose_fit.bind(group), .004)
			clip.loop_mode = Animation.LOOP_LINEAR
			assert(library.add_animation(Fits[group][0], clip) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		space.transform = source_space
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
		var output := PackedScene.new()
		assert(output.pack(model) == OK)
		assert(ResourceSaver.save(output, folder.path_join("giant-serpent-enhanced-%s.scn" % style),
			ResourceSaver.FLAG_COMPRESS) == OK)
		var target := folder.path_join("giant-serpent-enhanced-%s.scn" % style)
		var report := FileAccess.open(folder.path_join("bake-%s.json" % style), FileAccess.WRITE)
		report.store_string(JSON.stringify({"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(target)}))
		report.close()
		model.free()
		print("GIANT SERPENT FIT: ", style, " preserves its Classic and Enhanced keys and adds two movement clips")
	quit()


func collect_base_poses(player: AnimationPlayer, rig: Skeleton3D) -> void:
	walk_poses.clear()
	player.play("Walk", 0.)
	player.advance(0.)
	for frame in 81:
		player.seek(player.current_animation_length * float(frame) / 80., true)
		walk_poses.append(rotations(rig))
	quiet_pose = walk_poses[4].duplicate()
	player.stop()


func rotations(rig: Skeleton3D) -> Array[Quaternion]:
	var result: Array[Quaternion] = []
	for joint: String in PoseJoints:
		var index := rig.find_bone(joint)
		assert(index >= 0, joint)
		result.append(rig.get_bone_pose_rotation(index))
	return result


func pose_fit(rig: Skeleton3D, phase: float, group: int) -> void:
	match group:
		0:
			var gait: Array[Quaternion] = walk_poses[clampi(roundi(phase * 80.), 0, 80)]
			restore_rotations(rig, gait)
			var lift := .16 + .07 * sin(phase * TAU)
			turn_world(rig, "bip01 neck", Vector3.RIGHT, -lift)
			turn_world(rig, "bip01 head", Vector3.RIGHT, .45 * lift)
		25:
			restore_rotations(rig, quiet_pose)
			var sway := sin(phase * TAU) * .064
			turn_world(rig, "bip01 neck", Vector3.UP, sway)
			turn_world(rig, "bip01 neck3", Vector3.RIGHT, .07 * absf(sway))
			turn_world(rig, "bip01 tail2", Vector3.UP, -.23 + .56 * sway)
			turn_world(rig, "bip01 tail4", Vector3.UP, .29 - .73 * sway)


func restore_rotations(rig: Skeleton3D, pose: Array[Quaternion]) -> void:
	for index in PoseJoints.size():
		var bone := rig.find_bone(PoseJoints[index])
		rig.set_bone_pose_rotation(bone, pose[index])
	rig.force_update_all_bone_transforms()
