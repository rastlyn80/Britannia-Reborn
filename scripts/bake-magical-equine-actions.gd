# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Hip := "bip01"
const Common := ["bip01", "bip01 spine1", "bip01 neck1", "bip01 head", "bip01 tail",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 r thigh", "bip01 r calf"]
const Gaits := {0: "CombatWalk", 1: "CombatIdle", 29: "MountedWalk", 30: "MountedRun", 31: "MountedIdle"}
const BaseGroups := {22: "Walk", 24: "Run", 25: "Idle"}
const Motions := {
	122: {
		2: ["EquineSideFall", .94], 3: ["Death2", 1.06], 4: ["RearingStrike", .90], 5: ["HornLunge", .78],
		10: ["HeadRecoil", .61], 12: ["CastingRear", .84], 15: ["WarningRear", .78],
		26: ["QuietHeadCheck", .92], 27: ["HighFidget", .98], 28: ["GuardAlert", .64],
	},
	132: {
		2: ["EquineSideFall", .90], 3: ["Death2", .97], 4: ["LowSnap", .73], 5: ["RaisedForeStrike", .83],
		10: ["LowRecoil", .54], 11: ["DeepBow", .88], 12: ["HeadSweepCast", .76],
		15: ["WarningPaw", .49], 19: ["HoverGather", .92], 23: ["StretchAndRise", .94],
		27: ["ForwardFidget", .90], 28: ["GuardAlert", .64],
	},
}


func run() -> void:
	var folder := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--study="):
			folder = argument.trim_prefix("--study=").path_join("132")
	if not folder.is_absolute_path():
		printerr("Pass --study= with the absolute private folder containing 122 and 132.")
		quit(2)
		return
	var ok := bake_equine(folder.path_join("../122").simplify_path(), 122, "unicorn-grounded.scn")
	if ok:
		ok = bake_equine(folder, 132, "kirin-late-grounded.scn")
	quit(0 if ok else 1)


func bake_equine(folder: String, body: int, source: String) -> bool:
	var path := folder.path_join(source)
	var source_scene := load(path) as PackedScene
	if source_scene == null:
		return false
	var model := source_scene.instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var source_space := model.find_child("SourceSpace", true, false) as Node3D
	var rest_space := source_space.transform
	var skin := Ground.skin_points(mesh, rig)
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var groups := BaseGroups.duplicate()
	var joints := Common.filter(func(name: String): return rig.find_bone(name) >= 0)
	for group: int in Motions[body]:
		var row: Array = Motions[body][group]
		var motion := fit_grounded(player, rig, [skin], float(row[1]), Hip, joints, pose_group.bind(body, group), .006)
		if group == 19:
			motion.loop_mode = Animation.LOOP_LINEAR
			add_hover(motion, player, rig)
		assert(library.add_animation(row[0], motion) == OK)
		groups[group] = row[0]
	for group: int in Gaits:
		if group >= 29 and body != 132:
			continue
		var name: String = Gaits[group]
		var source_clip := "Walk" if group in [0, 29] else "Run" if group == 30 else "Idle"
		assert(library.add_animation(name, gait(player, rig, source_clip, body, group)) == OK)
		groups[group] = name
	verify_base_clips(player, path)
	player.stop()
	rig.reset_bone_poses()
	source_space.transform = rest_space
	var scene := PackedScene.new()
	var output := folder.path_join("enhanced-original.scn")
	if scene.pack(model) != OK or ResourceSaver.save(scene, output,
			ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_BUNDLE_RESOURCES) != OK:
		model.free()
		return false
	model.free()
	var evidence := FileAccess.open(folder.path_join("enhanced-bake.json"), FileAccess.WRITE)
	if evidence == null:
		return false
	evidence.store_line(JSON.stringify({"body": body, "groups": groups, "sha256": FileAccess.get_sha256(output),
		"original_scene_sha256": FileAccess.get_sha256(path), "authored_clips": groups.size() - BaseGroups.size()}, "  ", true))
	print("MAGICAL EQUINE BAKE: body ", body, ", ", groups.size(), " source groups and ", groups.size() - 3, " fitted motions")
	return groups.size() == (20 if body == 132 else 15)


func rotate_joint(rig: Skeleton3D, name: String, axis: Vector3, angle: float) -> void:
	if absf(angle) > .00001 and rig.find_bone(name) >= 0:
		turn_world(rig, name, axis, angle)


func shift_hip(rig: Skeleton3D, delta: Vector3) -> void:
	var index := rig.find_bone(Hip)
	var hip := rig.get_bone_global_pose(index)
	hip.origin += rig.global_basis.inverse() * delta
	rig.set_bone_global_pose(index, hip)


func pose_group(rig: Skeleton3D, phase: float, body: int, group: int) -> void:
	if group == 2 or group == 3:
		fall_pose(rig, phase, body, group)
		return
	var pulse := envelope(phase, .03, .30, .48, .97)
	var early := envelope(phase, .01, .20, .30, .63)
	var late := envelope(phase, .31, .56, .65, .96)
	var rear := 0.
	var reach := 0.
	var recoil := 0.
	var paw := 0.
	var turn := 0.
	match group:
		4:
			rear = .78 * pulse if body == 122 else .11 * late
			reach = .23 * late if body == 122 else .50 * early
			paw = .18 * late
		5:
			rear = .33 * early if body == 122 else .87 * pulse
			reach = .52 * late if body == 122 else .28 * late
			paw = .27 * pulse
		10:
			recoil = .48 * early
			reach = .20 * late if body == 122 else .56 * pulse
			turn = -.24 * pulse
		11:
			reach = .89 * pulse
			paw = .15 * pulse
		12:
			rear = .86 * pulse if body == 122 else .16 * early
			reach = .40 * late if body == 132 else .04 * pulse
			turn = .34 * pulse if body == 132 else .13 * pulse
		15:
			rear = .54 * early if body == 122 else .26 * pulse
			paw = .42 * pulse if body == 132 else .18 * late
		19:
			paw = .25 + .10 * sin(TAU * phase)
			rear = .23 + .06 * sin(TAU * phase)
			reach = -.07
		23:
			reach = .52 * early
			rear = .32 * late
			paw = .22 * late
		26:
			reach = .18 * pulse
			turn = .26 * sin(TAU * phase)
		27:
			rear = .78 * pulse if body == 122 else .09 * late
			reach = .37 * early if body == 132 else .06 * late
			turn = -.29 * pulse
		28:
			recoil = .18 * pulse
			turn = .11 * pulse
	var anchor := hind_midpoint(rig)
	rotate_joint(rig, Hip, Vector3.RIGHT, -1.02 * rear + .14 * reach)
	rotate_joint(rig, "bip01 spine1", Vector3.RIGHT, -.13 * rear + .30 * reach)
	rotate_joint(rig, "bip01 neck1", Vector3.RIGHT, .63 * reach - recoil + .15 * rear)
	rotate_joint(rig, "bip01 head", Vector3.RIGHT, -.16 * rear + .17 * reach - .36 * recoil)
	rotate_joint(rig, "bip01 head", Vector3.UP, turn)
	rotate_joint(rig, "bip01 tail", Vector3.RIGHT, -.30 * rear - .18 * reach)
	for side: String in ["l", "r"]:
		var raised := paw if side == "l" else paw * .43
		rotate_joint(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -.24 * rear - .53 * raised - .32 * reach)
		rotate_joint(rig, "bip01 " + side + " forearm", Vector3.RIGHT, .68 * rear + .63 * raised + .37 * reach)
		rotate_joint(rig, "bip01 " + side + " hand", Vector3.RIGHT, -.27 * raised)
		rotate_joint(rig, "bip01 " + side + " thigh", Vector3.RIGHT, .58 * rear)
		rotate_joint(rig, "bip01 " + side + " calf", Vector3.RIGHT, -.28 * rear)
	shift_hip(rig, (anchor - hind_midpoint(rig)).slide(Vector3.UP))


func fall_pose(rig: Skeleton3D, phase: float, body: int, group: int) -> void:
	var high := envelope(phase, .00, .19, .29, .55) * (1.0 if body == 122 else .65)
	var down := smoothstep(.22, .79, phase)
	var brace := envelope(phase, .12, .30, .49, .68)
	var side := 1. if group == 2 else -1.
	var roll := side * (1.55 if group == 2 else 2.81) * down
	rotate_joint(rig, Hip, Vector3.RIGHT, -.79 * high + (.13 if group == 2 else -.30) * down)
	rotate_joint(rig, Hip, Vector3.BACK, roll)
	rotate_joint(rig, Hip, Vector3.UP, side * .20 * down)
	rotate_joint(rig, "bip01 neck1", Vector3.RIGHT, .24 * high + .36 * down)
	rotate_joint(rig, "bip01 head", Vector3.UP, side * .30 * down)
	rotate_joint(rig, "bip01 tail", Vector3.BACK, -.32 * side * down)
	for leg: String in ["l", "r"]:
		var flex := .17 if (leg == "l") == (side > 0.) else .37
		rotate_joint(rig, "bip01 " + leg + " upperarm", Vector3.RIGHT, -.21 * high + flex * down)
		rotate_joint(rig, "bip01 " + leg + " forearm", Vector3.RIGHT, .75 * brace + .32 * down)
		rotate_joint(rig, "bip01 " + leg + " thigh", Vector3.RIGHT, .48 * high + .38 * down)
		rotate_joint(rig, "bip01 " + leg + " calf", Vector3.RIGHT, -.38 * down)
	shift_hip(rig, Vector3(side * .25 * down, 0., -.14 * down))


func add_hover(motion: Animation, player: AnimationPlayer, rig: Skeleton3D) -> void:
	var address := NodePath("%s:%s" % [player.get_node(player.root_node).get_path_to(rig), Hip])
	var track := motion.find_track(address, Animation.TYPE_POSITION_3D)
	var parent := rig.get_bone_parent(rig.find_bone(Hip))
	var local_up := (rig.global_basis * rig.get_bone_global_pose(parent).basis).inverse() * Vector3.UP
	for key in motion.track_get_key_count(track):
		var phase := motion.track_get_key_time(track, key) / motion.length
		var lift := .17 + .04 * sin(TAU * phase)
		motion.track_set_key_value(track, key, motion.track_get_key_value(track, key) + local_up * lift)


func gait(player: AnimationPlayer, rig: Skeleton3D, source_name: String, body: int, group: int) -> Animation:
	var source := player.get_animation(source_name)
	var motion := source.duplicate(true) as Animation
	motion.loop_mode = Animation.LOOP_LINEAR
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var tracks := {}
	for joint: String in ["bip01 neck1", "bip01 head", "bip01 tail"]:
		var track_path := NodePath("%s:%s" % [rig_path, joint])
		var track := motion.find_track(track_path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(track, track_path)
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		tracks[joint] = track
	player.play(source_name, 0.)
	player.advance(0.)
	for frame in 81:
		var phase := float(frame) / 80.
		var time := phase * source.length
		rig.reset_bone_poses()
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		var pulse := sin(TAU * phase)
		var base := (.32 if body == 122 else .19) if group == 0 else .07 if group == 1 else -.06
		rotate_joint(rig, "bip01 neck1", Vector3.RIGHT, base + .027 * pulse)
		rotate_joint(rig, "bip01 head", Vector3.RIGHT, -.36 * base + .021 * pulse)
		rotate_joint(rig, "bip01 tail", Vector3.UP, .067 * pulse)
		for joint: String in tracks:
			motion.rotation_track_insert_key(tracks[joint], time, rig.get_bone_pose_rotation(rig.find_bone(joint)))
	return motion
