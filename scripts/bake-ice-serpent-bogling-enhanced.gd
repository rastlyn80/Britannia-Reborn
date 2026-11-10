# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-serpent-harpy-enhanced.gd"

const ColdStage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/ice-serpent-bogling/"
const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const IceClips := {4: "IceSerpentCoilStrike", 23: "IceSerpentEmerge", 28: "IceSerpentHeadAlert"}
const IceLengths := {4: .82, 23: 1.16, 28: .81}
const BogClips := {23: "BoglingSprout", 28: "BoglingBranchAlert"}
const BogLengths := {23: 1.15, 28: .82}
const BranchJoints := ["spine", "spine.001", "spine.002", "spine.003", "spine.004", "spine.005", "spine.006",
	"shoulder.L.001", "shoulder.R.001", "upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R",
	"hand.L", "hand.R", "thigh.L", "thigh.R", "shin.L", "shin.R", "foot.L", "foot.R"]

func run() -> void:
	for body: int in [89, 779]:
		var row := Registry.entry(body)
		var assets := Profile.registered_assets(row)
		for treatment: String in assets:
			bake_body_motion(body, treatment, assets[treatment], row)
	quit()

func bake_body_motion(body: int, treatment: String, source: String, row: Dictionary) -> void:
	var expected: Variant = row.asset_sha256
	assert(FileAccess.get_sha256(source) == (expected[treatment] if expected is Dictionary else expected))
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
	var clips := IceClips if body == 89 else BogClips
	for group: int in clips:
		var motion: Animation
		if body == 89:
			motion = fit_grounded(player, rig, skins, IceLengths[group], RootJoint, Neck + Tail + ["bip01 ponytail1"],
				pose_ice.bind(group), .006)
			if group == 23:
				offset_root(motion, rig, func(phase: float): return -ice_depth(phase))
		else:
			motion = fit_grounded(player, rig, skins, BogLengths[group], "spine", BranchJoints, pose_bog.bind(group), .006)
			if group == 23:
				add_branch_scale(motion, player, rig)
		assert(library.add_animation(clips[group], motion) == OK)
	verify_base_clips(player, source)
	player.stop()
	rig.reset_bone_poses()
	var result := PackedScene.new()
	assert(result.pack(model) == OK)
	assert(ResourceSaver.save(result, ColdStage + "%d-%s.scn" % [body, treatment], ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("ICE SERPENT AND BOGLING ", body, "/", treatment, ": ", clips.size(), " fitted clips")

static func ice_depth(phase: float) -> float:
	return .39 * (1.0 - smoothstep(.04, .82, phase))

func pose_ice(rig: Skeleton3D, phase: float, group: int) -> void:
	var extension := 0.0
	var curl := 0.0
	var lift := 0.0
	var gaze := 0.0
	match group:
		4:
			extension = envelope(phase, .13, .36, .43, .66)
			curl = .78 * (1.0 - extension)
			lift = .77 - .49 * extension
			gaze = .13 * sin(PI * phase)
		23:
			extension = .70 - .32 * smoothstep(.32, .90, phase)
			lift = .22 + .15 * smoothstep(.35, .95, phase)
			gaze = .21 * sin(TAU * phase) * sin(PI * phase)
		28:
			var alert := smoothstep(.16, .87, phase)
			extension = .62 * (1.0 - alert)
			curl = .77 * alert
			lift = .22 + .71 * alert
			gaze = -.14 * sin(PI * phase)
	var forward := (joint_world(rig, Neck[-1]) - joint_world(rig, Neck[0])).slide(Vector3.UP).normalized()
	for i in Neck.size() - 1:
		var fraction := float(i) / float(Neck.size() - 2)
		var pivot := rig.find_bone(Neck[i])
		var tip := rig.find_bone(Neck[i + 1])
		var side := lerpf(.69, -.34, fraction) * curl
		var flat := forward.rotated(Vector3.UP, side)
		var up := lift * lerpf(.65, .90, fraction) - .18 * extension
		var from := rig.get_bone_global_pose(pivot).origin
		var rest_tip := rig.get_bone_global_pose(tip).origin
		var direction := (flat + Vector3.UP * up).normalized()
		var target := from + rig.global_basis.inverse() * direction * from.distance_to(rest_tip)
		Arms.aim(rig, pivot, tip, rest_tip.lerp(target, clampf(.24 + .69 * extension + .61 * curl, 0.0, 1.0)))
		rig.force_update_all_bone_transforms()
	turn_world(rig, Neck[-1], forward.cross(Vector3.UP), -.29 * lift)
	turn_world(rig, Neck[-1], Vector3.UP, gaze)
	turn_world(rig, "bip01 ponytail1", forward.cross(Vector3.UP), -.58 * extension)
	turn_world(rig, Tail[1], Vector3.UP, -.33 * curl + .24 * extension)
	turn_world(rig, Tail[2], Vector3.UP, -.46 * curl - .15 * gaze)
	turn_world(rig, Tail[3], Vector3.UP, -.39 * curl + .24 * extension)
	turn_world(rig, Tail[4], Vector3.UP, -.27 * curl + .18 * gaze)

static func branch_scale(phase: float) -> float:
	return lerpf(.14, 1.0, smoothstep(.10, .68, phase))

func add_branch_scale(motion: Animation, player: AnimationPlayer, rig: Skeleton3D) -> void:
	var path := NodePath("%s:spine" % player.get_node(player.root_node).get_path_to(rig))
	var channel := motion.find_track(path, Animation.TYPE_SCALE_3D)
	if channel < 0:
		channel = motion.add_track(Animation.TYPE_SCALE_3D)
		motion.track_set_path(channel, path)
	else:
		motion.track_remove_key(channel, 0)
	for index in 81:
		var phase := float(index) / 80.0
		motion.scale_track_insert_key(channel, phase * motion.length, Vector3.ONE * branch_scale(phase))

func pose_bog(rig: Skeleton3D, phase: float, group: int) -> void:
	var rise := group == 23
	var close := 1.0 - smoothstep(.10, .71, phase) if rise else .23 * envelope(phase, .03, .30, .49, .89)
	var flare := envelope(phase, .29, .61, .74, 1.0) if rise else envelope(phase, .13, .49, .62, .98)
	var tilt := .10 * sin(TAU * phase) * sin(PI * phase)
	if rise:
		var pivot := rig.find_bone("spine")
		assert(pivot >= 0 and rig.get_bone_parent(pivot) < 0)
		rig.set_bone_pose_scale(pivot, Vector3.ONE * branch_scale(phase))
		rig.force_update_all_bone_transforms()
	turn_world(rig, "spine", Vector3.RIGHT, .42 * close)
	turn_world(rig, "spine.001", Vector3.RIGHT, .32 * close - .17 * flare)
	turn_world(rig, "spine.003", Vector3.BACK, tilt)
	turn_world(rig, "spine.004", Vector3.RIGHT, .36 * close - .20 * flare)
	turn_world(rig, "spine.006", Vector3.UP, .26 * flare)
	for side: String in ["L", "R"]:
		var sign := 1.0 if side == "L" else -1.0
		turn_world(rig, "shoulder." + side + ".001", Vector3.BACK, sign * .30 * flare)
		turn_world(rig, "upper_arm." + side, Vector3.BACK, sign * (.87 * flare - .46 * close))
		turn_world(rig, "upper_arm." + side, Vector3.RIGHT, -.48 * close)
		turn_world(rig, "forearm." + side, Vector3.RIGHT, -.72 * close - .49 * flare)
		turn_world(rig, "hand." + side, Vector3.UP, sign * .34 * flare)
		turn_world(rig, "thigh." + side, Vector3.RIGHT, -.52 * close)
		turn_world(rig, "shin." + side, Vector3.RIGHT, .76 * close)
		turn_world(rig, "foot." + side, Vector3.RIGHT, -.29 * close)
