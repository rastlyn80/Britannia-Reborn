# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/frost-spider-enhanced/"
const Clips := {11: "FrostSpiderClawProbe", 12: "FrostSpiderAbdomenRise", 15: "FrostSpiderHighDefence",
	23: "FrostSpiderUnfold", 25: "FrostSpiderQuietRest", 26: "FrostSpiderSilkCheck",
	27: "FrostSpiderRockingSignal", 28: "FrostSpiderGather"}
const Durations := {11: .84, 12: .94, 15: .76, 23: .86, 25: 1.10, 26: 1.04, 27: 1.04, 28: .82}
const Legs := [
	["bone20", "bone21", "bone22"], ["bone16", "bone17", "bone18"],
	["bone24", "bone25", "bone26"], ["bone12", "bone13", "bone14"],
	["bone28", "bone29", "bone30"], ["bone08", "bone09", "bone10"],
	["bone32", "bone33", "bone34"], ["bone04", "bone05", "bone06"],
]


func run() -> void:
	var row := Registry.entry(20)
	var joints := ["bone01", "bone02"]
	for leg: Array in Legs:
		joints.append_array(leg.slice(0, 2))
	for treatment: String in row.assets:
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
			var clip := fit_grounded(player, rig, skins, Durations[group], "bone01", joints, pose_spider.bind(group), .004)
			if group == 25:
				clip.loop_mode = Animation.LOOP_LINEAR
			assert(library.add_animation(Clips[group], clip) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Destination + "20-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("FROST SPIDER ", treatment, ": ", Clips.size(), " fitted motions with retained source keys")
	quit()


func spider_envelope(phase: float, begin: float, peak: float, hold: float, finish: float) -> float:
	return smoothstep(begin, peak, phase) * (1.0 - smoothstep(hold, finish, phase))


func pose_spider(rig: Skeleton3D, phase: float, group: int) -> void:
	var lift := 0.0
	var reach := 0.0
	var spread := 0.0
	var fold := 0.0
	var pitch := 0.0
	var abdomen := 0.0
	var roll := 0.0
	var root_height := 0.0
	match group:
		11:
			var probe := spider_envelope(phase, .08, .37, .64, .97)
			lift = .22 * probe
			reach = .15 * probe
			pitch = .10 * probe
			roll = .11 * sin(TAU * phase) * probe
		12:
			var display := spider_envelope(phase, .08, .39, .66, .97)
			abdomen = .31 * display
			pitch = -.16 * display
			lift = .23 * display
			reach = .08 * display
			root_height = .035 * display
		15:
			var warning := spider_envelope(phase, .03, .31, .61, .96)
			lift = .79 * warning
			reach = -.12 * warning
			spread = .21 * warning
			pitch = -.27 * warning
			abdomen = -.23 * warning
		23:
			fold = 1.0 - smoothstep(.05, .66, phase)
			var open := spider_envelope(phase, .14, .46, .62, .93)
			lift = .38 * open
			spread = .23 * open
			root_height = -.30 * fold
			pitch = .14 * fold
			abdomen = -.31 * fold
		25:
			abdomen = .018 * (1.0 - cos(TAU * phase))
			root_height = .010 * sin(TAU * phase)
		26:
			var check := spider_envelope(phase, .09, .36, .68, .98)
			lift = .10 * check
			reach = .08 * check
			pitch = .09 * check
			abdomen = -.09 * check
			roll = .08 * sin(TAU * phase) * check
		27:
			var rock := spider_envelope(phase, .02, .28, .71, .98)
			lift = .44 * rock
			reach = .13 * rock
			pitch = -.14 * rock
			abdomen = .18 * rock
			roll = .22 * sin(TAU * phase) * rock
		28:
			var guard := spider_envelope(phase, .09, .43, .77, 1.0)
			fold = .18 * guard
			lift = .17 * guard
			pitch = .11 * guard
			root_height = -.09 * guard
	var anchors: Array[Vector3] = []
	for leg: Array in Legs:
		anchors.append(joint_world(rig, leg[2]))
	turn_world(rig, "bone01", Vector3.RIGHT, pitch)
	turn_world(rig, "bone01", Vector3.BACK, roll)
	turn_world(rig, "bone02", Vector3.RIGHT, abdomen)
	var root_index := rig.find_bone("bone01")
	var body_pose := rig.get_bone_global_pose(root_index)
	body_pose.origin += rig.global_basis.inverse() * Vector3.UP * root_height
	rig.set_bone_global_pose(root_index, body_pose)
	for index in Legs.size():
		var anchor := anchors[index]
		var side := 1.0 if index % 2 == 0 else -1.0
		var front := 1.0 if index < 2 else (.36 if index < 4 else 0.0)
		var directional_lift := lift * front * (1.0 + 1.2 * side * roll)
		var target := anchor + Vector3(
			side * spread * front - anchor.x * .43 * fold,
			directional_lift,
			reach * front - anchor.z * .43 * fold
		)
		aim_leg(rig, Legs[index], target)


func aim_leg(rig: Skeleton3D, leg: Array, world_target: Vector3) -> void:
	var hip := rig.find_bone(leg[0])
	var knee := rig.find_bone(leg[1])
	var tip := rig.find_bone(leg[2])
	var start := rig.get_bone_global_pose(hip).origin
	var bend := rig.get_bone_global_pose(knee).origin
	var end := rig.get_bone_global_pose(tip).origin
	var target := rig.to_local(world_target)
	var upper := start.distance_to(bend)
	var lower := bend.distance_to(end)
	var direction := (target - start).normalized()
	var distance := clampf(start.distance_to(target), absf(upper - lower) + .001, upper + lower - .001)
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var pole := (bend - start).slide(direction).normalized()
	var goal := start + direction * along + pole * sqrt(maxf(0.0, upper * upper - along * along))
	aim_segment(rig, hip, knee, goal)
	aim_segment(rig, knee, tip, start + direction * distance)


func aim_segment(rig: Skeleton3D, joint: int, child: int, goal: Vector3) -> void:
	var pose := rig.get_bone_global_pose(joint)
	var direction := (rig.get_bone_global_pose(child).origin - pose.origin).normalized()
	pose.basis = Basis(Quaternion(direction, (goal - pose.origin).normalized())) * pose.basis
	rig.set_bone_global_pose(joint, pose)
	rig.force_update_all_bone_transforms()
