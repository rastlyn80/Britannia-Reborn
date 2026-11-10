# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/evil-mage-plague-beast/"
const Mage := {23: "EvilMageManifest", 28: "EvilMageCrossedWard"}
const Beast := {4: "PlagueBeastMawLunge", 23: "PlagueBeastHatch", 25: "PlagueBeastFeedingFeelers",
	26: "PlagueBeastForearmWatch", 27: "PlagueBeastTongueDisplay", 28: "PlagueBeastTailAlert"}
const MageLengths := {23: 1.21, 28: .78}
const BeastLengths := {4: .91, 23: 1.32, 25: 1.12, 26: .97, 27: 1.02, 28: .82}
const MageJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]
const Mouths := ["face 1 jaw2", "face2 jaw2", "face3 jaw2", "face4 jaw2", "face5 jaw2"]
const Tendrils := ["tendril1", "tendril2", "tendril3", "tendril4s", "tendril5"]
const BeastJoints := ["bip 01", "upper mass", "arm l1", "arm l3", "arm r1", "arm r3",
	"tentaclea 1", "tentaclea 2", "tentacleb 1", "tentacleb 2", "tongue1", "tongue2", "tongue3"]


func run() -> void:
	for body: int in [124, 775]:
		var row := Registry.entry(body)
		for treatment: String in row.assets:
			bake_treatment(body, treatment, row)
	quit()


func bake_treatment(body: int, treatment: String, row: Dictionary) -> void:
	var source := Registry.asset_path(row, treatment)
	assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var skins: Array[Dictionary] = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			skins.append(Ground.skin_points(mesh, rig))
	assert(not skins.is_empty())
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var mage := body == 124
	var clips := Mage if mage else Beast
	var joints := MageJoints if mage else BeastJoints + Mouths + Tendrils
	var lengths := MageLengths if mage else BeastLengths
	for group: int in clips:
		var pose := pose_mage.bind(group) if mage else pose_beast.bind(group)
		var motion := fit_grounded(player, rig, skins, lengths[group], "__root", joints, pose, .006)
		if group == 23:
			bake_growth(motion, player, rig, body)
		assert(library.add_animation(clips[group], motion) == OK)
	verify_base_clips(player, source)
	player.stop()
	rig.reset_bone_poses()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed, Destination + "%d-%s.scn" % [body, treatment], ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("EVIL MAGE AND PLAGUE BEAST ", body, "/", treatment, ": ", clips.size(), " fitted motions")


static func size_for_rise(body: int, phase: float) -> float:
	if body == 124:
		return lerpf(.045, 1.0, smoothstep(.04, .61, phase))
	return lerpf(.085, 1.0, smoothstep(.16, .83, phase))


func bake_growth(motion: Animation, player: AnimationPlayer, rig: Skeleton3D, body: int) -> void:
	var path := NodePath("%s:__root" % player.get_node(player.root_node).get_path_to(rig))
	var channel := motion.find_track(path, Animation.TYPE_SCALE_3D)
	if channel < 0:
		channel = motion.add_track(Animation.TYPE_SCALE_3D)
		motion.track_set_path(channel, path)
	else:
		motion.track_remove_key(channel, 0)
	for frame in 81:
		var phase := float(frame) / 80.0
		motion.scale_track_insert_key(channel, phase * motion.length, Vector3.ONE * size_for_rise(body, phase))


func pose_mage(rig: Skeleton3D, phase: float, group: int) -> void:
	var rise := group == 23
	var crouch := 1.0 - smoothstep(.16, .66, phase) if rise else 0.0
	var ward := envelope(phase, .28, .62, .83, 1.0) if rise else smoothstep(.18, .71, phase)
	var dip := .12 * envelope(phase, .13, .31, .50, .84)
	if rise:
		rig.set_bone_pose_scale(rig.find_bone("__root"), Vector3.ONE * size_for_rise(124, phase))
		rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 pelvis", Vector3.RIGHT, .41 * crouch)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .40 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .32 * crouch - dip)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, -.22 * ward)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.47 * crouch + .13 * ward)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		var weight := .72 if side == "l" else 1.0
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.24 * crouch - .71 * ward * weight)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign * (.35 * ward - .22 * crouch))
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.63 * crouch - .73 * ward)
		turn_world(rig, "bip01 %s hand" % side, Vector3.UP, sign * .29 * ward)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.84 * crouch)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, 1.27 * crouch)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.46 * crouch)


func pose_beast(rig: Skeleton3D, phase: float, group: int) -> void:
	var curl := 0.0
	var lunge := 0.0
	var feed := 0.0
	var watch := 0.0
	var flick := 0.0
	match group:
		4:
			var windup := envelope(phase, .00, .16, .19, .34)
			var strike := envelope(phase, .17, .35, .46, .83)
			lunge = .14 + .86 * strike
			curl = -.85 * windup + .19 * strike
			var root := rig.find_bone("__root")
			var pose := rig.get_bone_global_pose(root)
			pose.origin += rig.global_basis.inverse() * Vector3.BACK * (.32 * strike - .11 * windup)
			rig.set_bone_global_pose(root, pose)
		23:
			curl = 1.0 - smoothstep(.49, .89, phase)
			watch = envelope(phase, .57, .77, .86, 1.0)
			rig.set_bone_pose_scale(rig.find_bone("__root"), Vector3.ONE * size_for_rise(775, phase))
			rig.force_update_all_bone_transforms()
		25:
			feed = .68 * envelope(phase, .04, .27, .75, 1.0)
			flick = .28 * sin(3.0 * TAU * phase) * sin(PI * phase)
		26:
			watch = envelope(phase, .08, .42, .62, .92)
			flick = .17 * sin(TAU * phase)
		27:
			feed = envelope(phase, .12, .35, .57, .86)
			flick = .31 * sin(TAU * phase) * sin(PI * phase)
		28:
			flick = envelope(phase, .12, .42, .70, 1.0)
			watch = -.28 * flick
	turn_world(rig, "bip 01", Vector3.RIGHT, .58 * curl + .53 * lunge)
	turn_world(rig, "upper mass", Vector3.RIGHT, .34 * curl + .24 * lunge - .29 * feed)
	turn_world(rig, "upper mass", Vector3.UP, .34 * watch - .24 * flick)
	turn_world(rig, "upper mass", Vector3.BACK, .20 * lunge - .19 * flick)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		var attention := .56 * watch * (1.0 if side == "l" else .39)
		turn_world(rig, "arm %s1" % side, Vector3.UP, sign * (-.75 * curl + .26 * lunge))
		turn_world(rig, "arm %s1" % side, Vector3.RIGHT, -.76 * curl - attention - .13 * lunge)
		turn_world(rig, "arm %s3" % side, Vector3.BACK, sign * (.53 * curl + .62 * attention))
	for i in Mouths.size():
		var open := .72 * lunge + (1.10 if i == 4 else .68) * feed - .38 * curl
		var flutter := .14 * sin((phase * 2.0 - float(i) * .11) * TAU) * feed
		turn_world(rig, Mouths[i], Vector3.RIGHT, open + flutter)
	for i in Tendrils.size():
		var sway := sin((phase - float(i) * .13) * TAU)
		turn_world(rig, Tendrils[i], Vector3.RIGHT, .73 * curl + .22 * lunge + .21 * feed * sway)
		turn_world(rig, Tendrils[i], Vector3.BACK, sway * (.21 * watch + .29 * flick))
	turn_world(rig, "tongue1", Vector3.RIGHT, 1.32 * feed + .19 * flick)
	turn_world(rig, "tongue2", Vector3.RIGHT, .68 * feed - .22 * flick)
	turn_world(rig, "tongue3", Vector3.RIGHT, .38 * feed)
	turn_world(rig, "tentaclea 1", Vector3.UP, -.60 * curl + 1.26 * flick)
	turn_world(rig, "tentaclea 2", Vector3.UP, .45 * curl + .61 * flick)
	turn_world(rig, "tentacleb 1", Vector3.UP, .48 * curl - 1.06 * flick)
	turn_world(rig, "tentacleb 2", Vector3.RIGHT, -.43 * curl + .56 * flick)

