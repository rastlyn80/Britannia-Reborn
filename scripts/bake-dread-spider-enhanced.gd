# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/poison-elemental-dread-spider/"
const DreadClips := {12: "DreadSpiderFrontExtend", 23: "DreadSpiderSilkEmergence", 26: "DreadSpiderQuietTwitch",
	27: "DreadSpiderRockBack", 28: "DreadSpiderAbdomenAlert"}
const DreadLengths := {12: 1.18, 23: 1.34, 26: .96, 27: 1.13, 28: .70}
const LegPairs := [
	[["bone20", "bone21"], ["bone16", "bone17"]],
	[["bone24", "bone25"], ["bone12", "bone13"]],
	[["bone28", "bone29"], ["bone08", "bone09"]],
	[["bone32", "bone33"], ["bone04", "bone05"]],
]


func run() -> void:
	var joints := ["bone01", "bone02"]
	for pair: Array in LegPairs:
		for leg: Array in pair:
			joints.append_array(leg)
	var row := Registry.entry(11)
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
		for group: int in DreadClips:
			var motion := fit_grounded(player, rig, skins, DreadLengths[group], "bone01", joints, pose_dread.bind(group), .005)
			assert(library.add_animation(DreadClips[group], motion) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Destination + "11-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("DREAD SPIDER ", treatment, ": five fitted motions with retained source keys")
	quit()


func pose_dread(rig: Skeleton3D, phase: float, group: int) -> void:
	var folded := 0.0
	var reach := 0.0
	var rock := 0.0
	var raised_abdomen := 0.0
	var twitch := 0.0
	match group:
		12:
			reach = smoothstep(.30, .53, phase) * (1.0 - smoothstep(.73, 1.0, phase))
			folded = .36 * (1.0 - smoothstep(.12, .53, phase))
			raised_abdomen = .24 * reach
			rock = .23 * reach
		23:
			folded = 1.0 - smoothstep(.12, .78, phase)
			reach = .70 * smoothstep(.12, .44, phase) * (1.0 - smoothstep(.51, .91, phase))
			rock = -.24 * folded
			raised_abdomen = .47 * smoothstep(.24, .53, phase) * (1.0 - smoothstep(.64, 1.0, phase))
		26:
			twitch = .14 * sin(TAU * phase) * sin(PI * phase)
			raised_abdomen = .045 * sin(TAU * phase)
		27:
			rock = .49 * smoothstep(.09, .51, phase) * (1.0 - smoothstep(.65, 1.0, phase))
			raised_abdomen = -.48 * rock
			folded = .22 * rock
		28:
			var alert := smoothstep(.16, .68, phase)
			raised_abdomen = .39 * alert
			folded = .21 * alert
			rock = -.13 * alert
	turn_world(rig, "bone01", Vector3.RIGHT, -rock)
	turn_world(rig, "bone02", Vector3.RIGHT, raised_abdomen)
	for index in LegPairs.size():
		var legs: Array = LegPairs[index]
		for side in legs.size():
			var leg: Array = legs[side]
			var sign_side := 1.0 if side == 0 else -1.0
			var front := 1.0 - float(index) / (LegPairs.size() - 1)
			var outward := sign_side * ((.32 + .22 * front) * folded - .42 * front * reach)
			turn_world(rig, leg[0], Vector3.UP, outward)
			turn_world(rig, leg[0], Vector3.RIGHT, rock * (.32 + .38 * front) - .64 * front * reach)
			turn_world(rig, leg[0], Vector3.BACK, -sign_side * (.34 * folded + twitch * front))
			turn_world(rig, leg[1], Vector3.BACK, sign_side * (.52 * folded + .12 * reach))
			turn_world(rig, leg[1], Vector3.RIGHT, .32 * front * reach + .19 * folded)
