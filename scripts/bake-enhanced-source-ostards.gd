# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-frenzied-ostard-enhanced.gd"

const DefaultOutput := "res://../work/creatures/enhanced-source-ostards-bake"
const Forms := {"desert": 210, "forest": 219}
const OstardGestures := {
	2: ["OstardRollFall", .96], 3: ["OstardForwardFall", .88],
	4: ["OstardForwardStrike", .64], 5: ["OstardLeapingKick", .56],
	10: ["OstardHeadRecoil", .32], 15: ["OstardCrouchAndRise", .48],
	23: ["OstardWakeAndCall", .80], 25: ["OstardPeaceIdle", .80],
	26: ["OstardHeadAndTailCheck", .96], 27: ["OstardHighCall", .80],
	28: ["OstardCombatReady", .56], 31: ["OstardSeatedIdle", .80],
}
const OstardGaits := {
	22: ["Walk", "OstardPeaceWalk", .80],
	29: ["Walk", "OstardSeatedWalk", .80],
	30: ["Run", "OstardSeatedRun", .80],
}
var output := DefaultOutput
var outputs := {}
const LegJoints := ["bip01 l horselink", "bip01 r horselink", "bip01 l foot", "bip01 r foot"]


func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output)) == OK)
	for style: String in Forms:
		bake_form(style)
	var receipt := FileAccess.open(output.path_join("bake-receipt.json"), FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify(outputs, "  ") + "\n")
	receipt.close()
	quit()


func bake_form(style: String) -> void:
	for treatment: String in ["original", "rounded", "modern"]:
		var path := "res://local-art/ostards/%s-%s.gltf" % [style, treatment]
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh, rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var joints := ["bip01"] + PoseJoints + LegJoints
		for group: int in OstardGestures:
			var entry: Array = OstardGestures[group]
			var clip := fit_grounded(player, rig, [skin], entry[1], "bip01", joints, pose_forest.bind(group), .004)
			if group in [25, 31]:
				clip.loop_mode = Animation.LOOP_LINEAR
			if group == 5:
				lift_kick(clip, player, rig)
			assert(library.add_animation(entry[0], clip) == OK)
		for group: int in OstardGaits:
			var row: Array = OstardGaits[group]
			var clip := fit_forest_gait(player, rig, row[0], row[2], group)
			assert(library.add_animation(row[1], clip) == OK)
		verify_base_clips(player, path)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		var name := "%d-%s.scn" % [Forms[style], treatment]
		var destination := output.path_join(name)
		assert(ResourceSaver.save(scene, destination, ResourceSaver.FLAG_COMPRESS) == OK)
		outputs[name] = {"source": FileAccess.get_sha256(path), "scene": FileAccess.get_sha256(destination)}
		model.free()
		print("OSTARD FIT ", style, "/", treatment, ": ", OstardGestures.size() + OstardGaits.size(), " fitted actions")


func pose_forest(rig: Skeleton3D, phase: float, group: int) -> void:
	if group in [2, 3]:
		pose_fall(rig, phase, group)
		return
	var dip := 0.0
	var rise := 0.0
	var brace := 0.0
	var tail := 0.0
	var trunk := 0.0
	var kick := 0.0
	var glance := 0.0
	match group:
		4:
			rise = .52 * envelope(phase, .0, .20, .30, .52)
			dip = .36 * envelope(phase, .24, .51, .69, 1.0)
			kick = .32 * envelope(phase, .08, .29, .41, .68)
			tail = -.47 * rise + .54 * dip
		5:
			kick = envelope(phase, .02, .24, .37, .60)
			brace = .81 * envelope(phase, .42, .66, .73, 1.0)
			trunk = -.83 * kick + .18 * brace
			rise = .37 * kick
			dip = .32 * brace
			tail = .76 * brace - .47 * kick
		10:
			rise = .81 * (1.0 - smoothstep(.08, .95, phase))
			tail = .38 - .62 * phase
		15:
			brace = .69 * envelope(phase, .0, .32, .49, .91)
			rise = .35 * smoothstep(.44, .95, phase)
			dip = .19 * (1.0 - smoothstep(.25, .83, phase))
			tail = .60 * brace - .33 * rise
		23:
			dip = .93 * (1.0 - smoothstep(.10, .38, phase))
			rise = .93 * envelope(phase, .16, .53, .68, 1.0)
			trunk = .14 * dip - .22 * rise
			brace = .47 * dip
			tail = .31 * rise - .41 * dip
		25:
			rise = .19 + .04 * sin(TAU * phase)
			tail = -.06 + .13 * sin(TAU * phase)
		26:
			dip = .18 * envelope(phase, .04, .23, .44, .68)
			rise = .22 * smoothstep(.44, .98, phase)
			tail = .46 * (1.0 - smoothstep(.05, .41, phase))
			glance = .14 * sin(PI * phase)
		27:
			dip = .35 * envelope(phase, .0, .17, .24, .43)
			rise = .98 * envelope(phase, .25, .51, .72, .99)
			tail = .34 * sin(TAU * phase + .7)
		28:
			rise = .26 * (1.0 - smoothstep(.0, .32, phase))
			dip = .60 * envelope(phase, .09, .39, .68, 1.0)
			brace = .22 * dip
		31:
			rise = .13 + .024 * sin(TAU * phase)
			tail = -.08 + .07 * sin(TAU * phase)
	turn_world(rig, "bip01", Vector3.RIGHT, trunk)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .13 * dip - .13 * rise)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .20 * dip - .20 * rise)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .37 * dip - .32 * rise + .25 * kick)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .31 * dip - .31 * rise + .16 * kick)
	turn_world(rig, "bip01 neck2", Vector3.RIGHT, .20 * dip - .22 * rise)
	turn_world(rig, "bip01 neck2", Vector3.UP, .48 * glance)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.17 * dip + .13 * rise)
	turn_world(rig, "bip01 head", Vector3.UP, .52 * glance)
	turn_world(rig, "bip01 ponytail1", Vector3.RIGHT, -.19 * tail)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.46 * tail)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, -.45 * tail)
	for side: String in ["l", "r"]:
		var strike := kick if side == "l" else .57 * kick
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.29 * brace - 1.27 * strike - trunk)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .41 * brace + .49 * strike)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.19 * brace - .35 * strike)


func pose_fall(rig: Skeleton3D, phase: float, group: int) -> void:
	var rolling := group == 2
	var bow := .38 * envelope(phase, .0, .10, .18, .34) if not rolling else 0.0
	var rear := envelope(phase, .04, .45, .57, .76) if rolling else envelope(phase, .12, .37, .41, .60)
	var fall := smoothstep(.55 if rolling else .42, .89 if rolling else .77, phase)
	turn_world(rig, "bip01", Vector3.FORWARD, (1.52 if rolling else -1.37) * fall)
	turn_world(rig, "bip01", Vector3.UP, (.33 if rolling else -.28) * fall)
	turn_world(rig, "bip01", Vector3.RIGHT, (.09 if rolling else .38) * fall - .16 * rear)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .21 * bow - .12 * rear)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .46 * bow - .34 * rear + .18 * fall)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .34 * bow - .35 * rear + .11 * fall)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .36 * bow - .10 * rear)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, .24 * rear - .18 * fall)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, .33 * rear + .17 * fall)
	for side: String in ["l", "r"]:
		var outward := 1.0 if side == "l" else -1.0
		var fold := .82 if (side == "l") == rolling else -.49
		turn_world(rig, "bip01 %s thigh" % side, Vector3.UP, outward * .24 * fall)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, fold * fall)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, -fold * .61 * fall)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, fold * .27 * fall)
	var land := smoothstep(.64 if rolling else .53, .94 if rolling else .86, phase)
	if land > 0.0:
		relax_fallen_leg(rig, "l", rolling, land)
		relax_fallen_leg(rig, "r", not rolling, land)


func relax_fallen_leg(rig: Skeleton3D, side: String, lower: bool, amount: float) -> void:
	var labels := ["thigh", "calf", "horselink", "foot", "toe0"]
	var heights := [-.16, -.135, -.14, -.11] if lower else [.17, .11, .09, .08]
	var hip := joint_world(rig, "bip01 pelvis")
	var space := rig.global_basis.inverse()
	for index in heights.size():
		var label := "bip01 %s %s" % [side, labels[index]]
		var tip := "bip01 %s %s" % [side, labels[index + 1]]
		var pivot := joint_world(rig, label)
		var direction := joint_world(rig, tip) - pivot
		var horizontal := direction.slide(Vector3.UP)
		if horizontal.length_squared() < .000001:
			continue
		var length := direction.length()
		var dy := clampf(hip.y + float(heights[index]) - pivot.y, -.80 * length, .80 * length)
		var target := horizontal.normalized() * sqrt(length * length - dy * dy) + Vector3.UP * dy
		var adjustment := Quaternion((space * direction).normalized(), (space * target).normalized())
		var bone := rig.find_bone(label)
		var pose := rig.get_bone_global_pose(bone)
		pose.basis = Basis(Quaternion.IDENTITY.slerp(adjustment, amount)) * pose.basis
		rig.set_bone_global_pose(bone, pose)
		rig.force_update_all_bone_transforms()


func lift_kick(clip: Animation, player: AnimationPlayer, rig: Skeleton3D) -> void:
	var path := NodePath("%s:bip01" % player.get_node(player.root_node).get_path_to(rig))
	var track := clip.find_track(path, Animation.TYPE_POSITION_3D)
	var axis := rig.global_basis.inverse() * Vector3.UP
	for key in clip.track_get_key_count(track):
		var phase := clip.track_get_key_time(track, key) / clip.length
		var height := .32 * envelope(phase, .0, .24, .35, .61)
		clip.track_set_key_value(track, key, clip.track_get_key_value(track, key) + axis * height)


func fit_forest_gait(player: AnimationPlayer, rig: Skeleton3D, seed: String, length: float, group: int) -> Animation:
	var clip := fit_gait(player, rig, seed, length, group)
	# The forest reference holds the neck higher on a peaceful walk.
	if group == 22:
		var path := NodePath("%s:bip01 neck" % player.get_node(player.root_node).get_path_to(rig))
		var track := clip.find_track(path, Animation.TYPE_ROTATION_3D)
		var axis := rig.global_basis.inverse() * Vector3.RIGHT
		var parent := rig.get_bone_parent(rig.find_bone("bip01 neck"))
		axis = rig.get_bone_global_rest(parent).basis.inverse() * axis
		var correction := Quaternion(axis.normalized(), -.12)
		for key in clip.track_get_key_count(track):
			clip.track_set_key_value(track, key, correction * clip.track_get_key_value(track, key))
	return clip
