# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/giant-black-widow-juka-mage/"
const Widow := {12: "GiantBlackWidowLegReach", 23: "GiantBlackWidowUnfold",
	26: "GiantBlackWidowAbdomenCheck", 27: "GiantBlackWidowRearBrace", 28: "GiantBlackWidowReadyAlert"}
const WidowLengths := {12: .96, 23: 1.12, 26: .90, 27: 1.13, 28: .86}
const Mage := {23: "JukaMageUnbow", 28: "JukaMageStepReady"}
const MageLengths := {23: 1.03, 28: .66}
const Pairs := [
	[["bone20", "bone21", "bone22"], ["bone16", "bone17", "bone18"]],
	[["bone24", "bone25", "bone26"], ["bone12", "bone13", "bone14"]],
	[["bone28", "bone29", "bone30"], ["bone08", "bone09", "bone10"]],
	[["bone32", "bone33", "bone34"], ["bone04", "bone05", "bone06"]],
]
const MageJoints := ["bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 r upperarm", "bip01 r forearm",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]


func run() -> void:
	bake_widow()
	prepare_body(765, Mage, MageLengths, MageJoints, pose_mage, Destination)
	quit()


func bake_widow() -> void:
	var joints := ["bone01", "bone02"]
	for pair: Array in Pairs:
		for leg: Array in pair:
			joints.append_array(leg)
	var row := Registry.entry(157)
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var body := model.find_child("Body", true, false) as MeshInstance3D
		var skins: Array[Dictionary] = [Ground.skin_points(body, rig)]
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		for group: int in Widow:
			var fit := fit_grounded(player, rig, skins, WidowLengths[group], "bone01", joints,
				pose_widow.bind(group), .005)
			if group == 23:
				bake_unfold_scale(fit, player, rig)
			assert(library.add_animation(Widow[group], fit) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Destination + "157-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("GIANT BLACK WIDOW ", treatment, ": five fitted motions with retained source keys")


func unfold_scale(phase: float) -> Vector3:
	return Vector3.ONE * lerpf(.07, 1.0, smoothstep(.015, .59, phase))


func bake_unfold_scale(motion: Animation, player: AnimationPlayer, rig: Skeleton3D) -> void:
	var path := NodePath("%s:__root" % player.get_node(player.root_node).get_path_to(rig))
	var track := motion.find_track(path, Animation.TYPE_SCALE_3D)
	if track < 0:
		track = motion.add_track(Animation.TYPE_SCALE_3D)
		motion.track_set_path(track, path)
	else:
		motion.track_remove_key(track, 0)
	for frame in 81:
		var phase := float(frame) / 80.0
		motion.scale_track_insert_key(track, phase * motion.length, unfold_scale(phase))


func pose_widow(rig: Skeleton3D, phase: float, group: int) -> void:
	var fold := 0.0
	var reach := 0.0
	var abdomen := 0.0
	var pitch := 0.0
	var side_check := 0.0
	var pulse := sin(PI * phase)
	match group:
		12:
			reach = envelope(phase, .13, .47, .55, .91)
			pitch = -.18 * reach
			abdomen = .23 * reach
		23:
			rig.set_bone_pose_scale(rig.find_bone("__root"), unfold_scale(phase))
			rig.force_update_all_bone_transforms()
			fold = 1.0 - smoothstep(.04, .76, phase)
			reach = .46 * envelope(phase, .19, .46, .59, .91)
			abdomen = .29 * fold
			pitch = .31 * fold
		26:
			side_check = .16 * pulse * sin(TAU * phase)
			abdomen = .14 * pulse
		27:
			abdomen = .55 * envelope(phase, .04, .42, .62, .96)
			pitch = -.42 * abdomen
			reach = .20 * abdomen
		28:
			var alert := smoothstep(.16, .81, phase)
			abdomen = .31 * alert
			pitch = .19 * alert
			side_check = -.21 * alert
	turn_world(rig, "bone01", Vector3.RIGHT, pitch)
	turn_world(rig, "bone02", Vector3.RIGHT, abdomen)
	turn_world(rig, "bone02", Vector3.UP, side_check)
	for index in Pairs.size():
		var front := 1.0 - float(index) / 3.0
		for side in 2:
			var sign_x := 1.0 if side == 0 else -1.0
			var leg: Array = Pairs[index][side]
			turn_world(rig, leg[0], Vector3.UP, sign_x * (.54 * fold - .52 * reach * front))
			turn_world(rig, leg[0], Vector3.RIGHT, -.44 * reach * front + .26 * fold * (1.0 - 2.0 * front))
			turn_world(rig, leg[0], Vector3.BACK, -sign_x * (.27 * fold + side_check * front))
			turn_world(rig, leg[1], Vector3.BACK, sign_x * (.68 * fold - .16 * reach * front))
			turn_world(rig, leg[1], Vector3.RIGHT, .28 * fold + .22 * reach * front)
			turn_world(rig, leg[2], Vector3.UP, sign_x * .21 * fold)


func pose_mage(rig: Skeleton3D, phase: float, group: int) -> void:
	var unbow := 1.0 - smoothstep(.08, .75, phase) if group == 23 else 0.0
	var ready := smoothstep(.14, .87, phase) if group == 28 else 0.0
	var sweep := envelope(phase, .04, .37, .53, .91) if group == 28 else 0.0
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .68 * unbow + .24 * ready)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, .48 * unbow + .21 * ready)
	turn_world(rig, "bip01 spine2", Vector3.UP, .26 * sweep)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .21 * unbow - .22 * ready)
	turn_world(rig, "bip01 head", Vector3.UP, -.21 * sweep)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -.56 * unbow + .45 * ready)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, .51 * unbow - .26 * ready)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -.31 * unbow + .68 * sweep)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, .44 * unbow - .47 * sweep)
	turn_world(rig, "bip01 l thigh", Vector3.RIGHT, -.35 * ready - .14 * unbow)
	turn_world(rig, "bip01 l calf", Vector3.RIGHT, .22 * ready + .19 * unbow)
	turn_world(rig, "bip01 l foot", Vector3.RIGHT, .13 * ready)
	turn_world(rig, "bip01 r thigh", Vector3.RIGHT, .12 * ready - .16 * unbow)
	turn_world(rig, "bip01 r calf", Vector3.RIGHT, .20 * unbow)
