# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-skeletal-mount-enhanced.gd"
## Fit the decoded reference choreography to each original weighted rig.

const HorseFits := {
	1: ["HorseCombatIdle", 1.00], 2: ["HorseSideFall", 1.00], 3: ["Death2", 1.20],
	4: ["HorseRearStrike", 1.00], 10: ["HorseHeadRecoil", 1.00], 12: ["HorseRearCast", 1.40],
	15: ["HorseForelegGuard", 1.00], 26: ["HorseQuietNod", 1.00], 27: ["HorseHighFidget", 1.00],
	28: ["HorseAlert", .80],
}


func run() -> void:
	var folder: String = get_script().resource_path.get_base_dir().path_join("prepared")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--study="):
			folder = argument.trim_prefix("--study=")
	for name: String in ["war-horse", "pack-horse"]:
		var source := folder.path_join(name + "-source.scn")
		var actor := (load(source) as PackedScene).instantiate()
		root.add_child(actor)
		var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var space := actor.find_child("SourceSpace", true, false) as Node3D
		var original_space := space.transform
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var skins: Array[Dictionary] = []
		for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
			skins.append(Ground.skin_points(mesh, rig))
		var pack := name == "pack-horse"
		for group: int in HorseFits:
			if group == 12 and not pack:
				continue
			# Pack group 28 supplies one neutral pose per direction.
			var duration := .12 if pack and group == 28 else float(HorseFits[group][1])
			var clip := fit_grounded(player, rig, skins, duration, Hip, MotionJoints,
				pose_horse.bind(group, pack), .004)
			if group == 1:
				clip.loop_mode = Animation.LOOP_LINEAR
			assert(library.add_animation(HorseFits[group][0], clip) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		space.transform = original_space
		var result := PackedScene.new()
		assert(result.pack(actor) == OK)
		assert(ResourceSaver.save(result, folder.path_join(name + "-enhanced.scn"), ResourceSaver.FLAG_COMPRESS) == OK)
		actor.free()
		print("WAR AND PACK HORSE BAKE: ", name, ", ", HorseFits.size() - (0 if pack else 1),
			" fitted clips and every original clip preserved")
	quit()


func pose_horse(rig: Skeleton3D, phase: float, group: int, pack: bool) -> void:
	match group:
		3:
			turned_collapse(rig, phase)
		10:
			var dip := envelope(phase, 0., .12, .16, .31)
			var jerk := envelope(phase, .14, .34, .43, .73)
			var reset := envelope(phase, .60, .74, .78, .93)
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.09 * jerk)
			turn_world(rig, "bip01 neck", Vector3.RIGHT, .19 * dip - .28 * jerk + .11 * reset)
			turn_world(rig, "bip01 neck1", Vector3.RIGHT, .15 * dip - .22 * jerk)
			turn_world(rig, "bip01 head", Vector3.RIGHT, .14 * dip + .20 * jerk - .14 * reset)
			turn_world(rig, "bip01 head", Vector3.UP, -.18 * jerk)
		26:
			var nod := envelope(phase, .11, .42, .56, .94)
			turn_world(rig, "bip01 neck1", Vector3.RIGHT, .24 * nod)
			turn_world(rig, "bip01 head", Vector3.RIGHT, .14 * nod)
		28:
			if not pack:
				var raise := envelope(phase, .10, .36, .56, .95)
				turn_world(rig, "bip01 neck1", Vector3.RIGHT, -.10 * raise)
				turn_world(rig, "bip01 head", Vector3.UP, .10 * raise)
				turn_world(rig, "bip01 tail1", Vector3.UP, .25 * raise)
		_:
			pose_group(rig, phase, group)


func turned_collapse(rig: Skeleton3D, phase: float) -> void:
	var lift := envelope(phase, .04, .24, .38, .65)
	var down := smoothstep(.39, .86, phase)
	var tuck := envelope(phase, .15, .38, .66, .91)
	# The front and rear directions show a quarter-turn before the
	# opposite flank lands. Keep the torso horizontal at rest.
	turn_world(rig, Hip, Vector3.RIGHT, -.97 * lift)
	turn_world(rig, Hip, Vector3.BACK, -1.78 * down)
	turn_world(rig, Hip, Vector3.UP, 1.34 * down)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .24 * lift)
	turn_world(rig, "bip01 head", Vector3.UP, .15 * down)
	turn_world(rig, "bip01 tail", Vector3.UP, -.30 * down)
	for side: String in ["l", "r"]:
		var fold := 1. if side == "l" else .66
		turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -.29 * lift + .22 * down)
		turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, .71 * tuck + .23 * down * fold)
		turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, .50 * lift + .21 * down)
		turn_world(rig, "bip01 " + side + " calf", Vector3.RIGHT, -.31 * down * fold)
	shift_hip(rig, Vector3(-.37 * down, 0., -.16 * down))
