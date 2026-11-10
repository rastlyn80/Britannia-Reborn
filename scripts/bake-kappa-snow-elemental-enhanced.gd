# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/kappa-snow-elemental/"
const Kappa := {12: "KappaShellLunge", 23: "KappaShellRise", 26: "KappaSnoutWatch",
	27: "KappaSpreadGuard", 28: "KappaStartledHop"}
const Snow := {23: "SnowElementalPackRise", 28: "SnowElementalShoulderAlert"}
const KappaLengths := {12: .84, 23: 1.19, 26: .98, 27: .94, 28: .82}
const SnowLengths := {23: 1.29, 28: .72}
const BipedJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]


func run() -> void:
	for body: int in [240, 163]:
		var row := Registry.entry(body)
		for treatment: String in Profile.registered_assets(row):
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
	var kappa := body == 240
	var clips := Kappa if kappa else Snow
	var lengths := KappaLengths if kappa else SnowLengths
	for group: int in clips:
		var motion: Animation
		if kappa:
			motion = fit_grounded(player, rig, skins, lengths[group], "__root", BipedJoints + ["bone01"],
				pose_kappa.bind(group), .006)
			if group == 28:
				bake_hop(motion, player, rig)
		else:
			motion = fit_grounded(player, rig, skins, lengths[group], "__root", BipedJoints, pose_snow.bind(group), .006)
			if group == 23:
				bake_compaction(motion, player, rig)
		assert(library.add_animation(clips[group], motion) == OK)
	verify_base_clips(player, source)
	player.stop()
	rig.reset_bone_poses()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed, Destination + "%d-%s.scn" % [body, treatment], ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("KAPPA AND SNOW ELEMENTAL ", body, "/", treatment, ": ", clips.size(), " fitted motions")


static func hop_height(phase: float) -> float:
	var airborne := clampf((phase - .17) / .54, 0.0, 1.0)
	return .43 * 4.0 * airborne * (1.0 - airborne)


func bake_hop(motion: Animation, player: AnimationPlayer, rig: Skeleton3D) -> void:
	var path := NodePath("%s:__root" % player.get_node(player.root_node).get_path_to(rig))
	var channel := motion.find_track(path, Animation.TYPE_POSITION_3D)
	assert(channel >= 0)
	var up := rig.global_basis.inverse() * Vector3.UP
	for index in motion.track_get_key_count(channel):
		var phase := motion.track_get_key_time(channel, index) / motion.length
		var old: Vector3 = motion.track_get_key_value(channel, index)
		motion.track_set_key_value(channel, index, old + up * hop_height(phase))


static func snow_scale(rig: Skeleton3D, phase: float) -> Vector3:
	var unfold := smoothstep(.15, .91, phase)
	var local_up := (rig.global_basis * rig.get_bone_global_rest(rig.find_bone("__root")).basis).inverse() * Vector3.UP
	var vertical := local_up.normalized().abs()
	return Vector3.ONE * lerpf(1.13, 1.0, unfold) - vertical * lerpf(.94, 0.0, unfold)


func bake_compaction(motion: Animation, player: AnimationPlayer, rig: Skeleton3D) -> void:
	var path := NodePath("%s:__root" % player.get_node(player.root_node).get_path_to(rig))
	var channel := motion.find_track(path, Animation.TYPE_SCALE_3D)
	if channel < 0:
		channel = motion.add_track(Animation.TYPE_SCALE_3D)
		motion.track_set_path(channel, path)
	else:
		motion.track_remove_key(channel, 0)
	for frame in 81:
		var phase := float(frame) / 80.0
		motion.scale_track_insert_key(channel, phase * motion.length, snow_scale(rig, phase))


func pose_kappa(rig: Skeleton3D, phase: float, group: int) -> void:
	var fold := 0.0
	var reach := 0.0
	var spread := 0.0
	var jaw := 0.0
	var hop := 0.0
	var turn := 0.0
	match group:
		12:
			fold = .67 * envelope(phase, .03, .20, .45, .81)
			reach = envelope(phase, .15, .46, .64, .95)
			jaw = .27 + .57 * reach
			turn = .31 * sin(TAU * phase)
		23:
			fold = .84 * (1.0 - smoothstep(.11, .78, phase))
			spread = .81 * envelope(phase, .21, .53, .69, .98)
			reach = .29 * spread
			jaw = .53 * envelope(phase, .10, .38, .69, .94)
			turn = -.49 * sin(PI * phase)
		26:
			reach = .48 * envelope(phase, .14, .48, .64, 1.0)
			jaw = .66 * smoothstep(.42, .71, phase)
		27:
			fold = .36 * envelope(phase, .08, .27, .36, .51)
			spread = .87 * envelope(phase, .20, .48, .72, 1.0)
			jaw = .69 * spread
			turn = -.44 * spread
		28:
			hop = hop_height(phase) / .43
			fold = .45 * envelope(phase, .02, .13, .19, .30) + .49 * envelope(phase, .57, .72, .78, .99)
			spread = .90 * hop
			jaw = .69 * envelope(phase, .43, .71, .88, 1.0)
			turn = .40 * hop
	turn_world(rig, "bip01 pelvis", Vector3.RIGHT, .34 * fold - .23 * hop)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .30 * fold + .26 * reach)
	turn_world(rig, "bip01 spine1", Vector3.UP, turn)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, .29 * fold - .21 * spread)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.34 * fold + .21 * reach)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .24 * reach - .31 * spread)
	turn_world(rig, "bone01", Vector3.RIGHT, jaw)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		var weight := .65 if side == "l" else 1.0
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.74 * reach * weight - .45 * fold)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign * (.96 * spread - .26 * fold))
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.76 * fold + .38 * reach)
		turn_world(rig, "bip01 %s hand" % side, Vector3.UP, sign * .34 * spread)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.76 * fold - .59 * hop * weight)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, 1.12 * fold + .81 * hop * weight)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.31 * fold - .25 * hop)


func pose_snow(rig: Skeleton3D, phase: float, group: int) -> void:
	var assembling := group == 23
	var curl := 1.0 - smoothstep(.26, .89, phase) if assembling else 0.0
	var alert := .30 * envelope(phase, .14, .41, .67, .98)
	var weight_shift := sin(TAU * phase) * (1.0 - curl)
	turn_world(rig, "bip01 pelvis", Vector3.RIGHT, .37 * curl)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .47 * curl + .15 * alert)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .57 * curl)
	turn_world(rig, "bip01 spine2", Vector3.BACK, -.19 * weight_shift)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .26 * curl)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.34 * curl - .29 * alert)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.42 * curl - .55 * alert)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, sign * (.34 * curl + .45 * alert))
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -1.19 * curl - .57 * alert)
		turn_world(rig, "bip01 %s hand" % side, Vector3.UP, sign * .30 * curl)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.89 * curl)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, 1.36 * curl)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.37 * curl)
	if assembling:
		rig.set_bone_pose_scale(rig.find_bone("__root"), snow_scale(rig, phase))
		rig.force_update_all_bone_transforms()
