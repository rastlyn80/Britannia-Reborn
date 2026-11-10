# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-orc-enhanced.gd"

const OutputFolder := "res://../work/creatures/native-form-audit/enhanced-source-gaps/field-enhanced/"
const DoeClips := {4: "DoeBowThrust", 15: "DoeRearRecoil", 25: "DoeQuietStand", 26: "DoeGlance", 28: "DoeAlert"}
const DoeLengths := {4: .5, 15: .7, 25: 1.1, 26: .7, 28: .4}
const DoeJoints := ["bip01 spine", "bip01 spine1", "bip01 neck", "bip01 neck1", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 r upperarm", "bip01 r forearm",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot",
	"bip01 ponytail1", "bip01 ponytail2", "bip01 tail"]
const RabbitClips := {4: "RabbitSettleFromRear", 25: "RabbitQuietCrouch", 26: "RabbitLookAround", 28: "RabbitRiseAlert"}
const RabbitLengths := {4: .5, 25: .24, 26: .7, 28: .30}
const RabbitJoints := ["Hips", "Spine", "Spine.001", "Neck", "Head",
	"Ear_L", "Ear_L.001", "Ear_R", "Ear_R.001", "Tail",
	"FrontUpLeg_L", "FrontLeg_L", "FrontUpLeg_R", "FrontLeg_R",
	"BackUpLeg_L", "BackUpLeg_R", "BackLeg_L", "BackLeg_R"]
const SheepClips := {25: "SheepQuietStand", 26: "SheepLookDown"}
const SheepLengths := {25: .7, 26: 1.0}
const SheepJoints := ["bip01 spine", "bip01 spine1", "bip01 neck", "bip01 neck1", "bip01 head",
	"bip01 ponytail1", "bip01 ponytail2", "bip01 tail"]
const StagClips := {4: "StagAntlerBow", 15: "StagRearRecoil", 25: "StagQuietStand", 26: "StagAntlerGlance",
	27: "StagPawStamp", 28: "StagAntlerAlert"}
const StagLengths := {4: .5, 15: .7, 25: 1.1, 26: .7, 27: .4, 28: .4}

func run() -> void:
	bake_field_body(237, DoeClips, DoeLengths, "bip01", DoeJoints, pose_doe, .004)
	bake_field_body(205, RabbitClips, RabbitLengths, "Hips", RabbitJoints, pose_rabbit, .003)
	for body: int in [207, 223]:
		bake_field_body(body, SheepClips, SheepLengths, "bip01", SheepJoints, pose_sheep, .004)
	bake_field_body(234, StagClips, StagLengths, "bip01", DoeJoints, pose_stag, .004)
	quit()

func bake_field_body(body: int, clips: Dictionary, lengths: Dictionary, root_joint: String, joints: Array,
		pose: Callable, gap: float) -> void:
	var row := Registry.entry(body)
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
		var source_sha := FileAccess.get_sha256(source)
		assert(not source_sha.is_empty() and source_sha == row.get("asset_sha256", {}).get(treatment, source_sha))
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var skins: Array[Dictionary] = []
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			skins.append(Ground.skin_points(mesh, rig))
		for group: int in clips:
			var fitted := fit_grounded(player, rig, skins, lengths[group], root_joint, joints, pose.bind(group), gap)
			assert(library.add_animation(clips[group], fitted) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		var target := OutputFolder + "%d-%s.scn" % [body, treatment]
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, target, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("FIELD ENHANCED BAKE ", body, "/", treatment, ": ", clips.size(), " new clips on the retained rig")

static func verify_base_clips(player: AnimationPlayer, source: String) -> void:
	var original := (load(source) as PackedScene).instantiate()
	var prior := original.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for name: String in prior.get_animation_list():
		var before := prior.get_animation(name)
		var after := player.get_animation(name)
		assert(before.length == after.length and before.get_track_count() == after.get_track_count())
		for track in before.get_track_count():
			assert(before.track_get_path(track) == after.track_get_path(track))
			assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track))
	original.free()

func pose_doe(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := sin(PI * phase)
	match group:
		4:
			var bow := smoothstep(0.0, .28, phase) * (1.0 - smoothstep(.48, .90, phase))
			var release := smoothstep(.48, .75, phase) * (1.0 - smoothstep(.81, 1.0, phase))
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, .20 * bow - .08 * release)
			turn_world(rig, "bip01 neck", Vector3.RIGHT, .48 * bow - .16 * release)
			turn_world(rig, "bip01 head", Vector3.RIGHT, .15 * bow)
			for side: String in ["r", "l"]:
				turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -.22 * bow + .14 * release)
				turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, .26 * bow)
		15:
			var hind_anchor := hind_midpoint(rig)
			var rear := smoothstep(.12, .42, phase) * (1.0 - smoothstep(.60, .94, phase))
			var gather := smoothstep(0.0, .14, phase) * (1.0 - smoothstep(.18, .39, phase))
			turn_world(rig, "bip01 spine", Vector3.RIGHT, -.74 * rear + .14 * gather)
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.14 * rear)
			turn_world(rig, "bip01 neck", Vector3.RIGHT, .22 * rear + .30 * gather)
			turn_world(rig, "bip01 head", Vector3.RIGHT, .12 * rear - .18 * gather)
			for side: String in ["r", "l"]:
				turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -.70 * rear)
				turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, .60 * rear)
				turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, .43 * rear)
				turn_world(rig, "bip01 " + side + " calf", Vector3.RIGHT, -.26 * rear)
				turn_world(rig, "bip01 " + side + " foot", Vector3.RIGHT, .21 * rear)
			var offset := hind_anchor - hind_midpoint(rig)
			offset.y = 0.0
			var joint := rig.find_bone("bip01")
			var placement := rig.get_bone_global_pose(joint)
			placement.origin += rig.global_basis.inverse() * offset
			rig.set_bone_global_pose(joint, placement)
			rig.force_update_all_bone_transforms()
		25:
			var breath := sin(TAU * phase)
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, .025 * breath)
			turn_world(rig, "bip01 neck1", Vector3.RIGHT, .040 * breath)
			turn_world(rig, "bip01 head", Vector3.RIGHT, -.024 * breath)
		26:
			turn_world(rig, "bip01 neck", Vector3.RIGHT, -.19 * pulse)
			turn_world(rig, "bip01 neck1", Vector3.UP, .24 * pulse)
			turn_world(rig, "bip01 head", Vector3.UP, .20 * pulse)
			turn_world(rig, "bip01 ponytail1", Vector3.UP, .12 * pulse)
			turn_world(rig, "bip01 ponytail2", Vector3.UP, -.18 * pulse)
		28:
			var lift := smoothstep(.05, .62, phase)
			turn_world(rig, "bip01 neck", Vector3.RIGHT, .20 - .44 * lift)
			turn_world(rig, "bip01 neck1", Vector3.RIGHT, .12 - .17 * lift)
			turn_world(rig, "bip01 head", Vector3.RIGHT, -.08 * lift)
			turn_world(rig, "bip01 ponytail1", Vector3.RIGHT, -.15 * lift)
			turn_world(rig, "bip01 ponytail2", Vector3.RIGHT, -.16 * lift)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.08 * pulse)

func hind_midpoint(rig: Skeleton3D) -> Vector3:
	return (joint_world(rig, "bip01 l foot") + joint_world(rig, "bip01 r foot")) * .5

func pose_rabbit(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := sin(PI * phase)
	var pitch := 0.0
	var ear := 0.0
	var upright := 0.0
	match group:
		4:
			upright = (1.0 - smoothstep(.10, .60, phase)) * .88
			pitch = -.24 * pulse
			ear = -.23 * pulse
		25:
			pitch = .045 * smoothstep(0.0, .10 / .24, phase)
			ear = .038 * smoothstep(0.0, .10 / .24, phase)
		26:
			pitch = -.13 * pulse
			ear = .32 * pulse
			turn_world(rig, "Head", Vector3.UP, .46 * pulse)
		28:
			upright = .64 * smoothstep(.15, .86, phase)
			pitch = .12 * (1.0 - smoothstep(.15, .86, phase))
			ear = -.29 * smoothstep(.24, .85, phase)
	var anchor := (joint_world(rig, "BackPaw_L") + joint_world(rig, "BackPaw_R")) * .5
	turn_world(rig, "Spine", Vector3.RIGHT, -.52 * upright + pitch)
	turn_world(rig, "Spine.001", Vector3.RIGHT, -.34 * upright)
	turn_world(rig, "Neck", Vector3.RIGHT, .19 * upright + .4 * pitch)
	turn_world(rig, "Head", Vector3.RIGHT, .20 * upright)
	for side: String in ["L", "R"]:
		var sign_x := 1.0 if side == "L" else -1.0
		turn_world(rig, "Ear_" + side, Vector3.BACK, sign_x * ear)
		turn_world(rig, "Ear_" + side + ".001", Vector3.RIGHT, -.21 * upright)
		turn_world(rig, "FrontUpLeg_" + side, Vector3.RIGHT, -.42 * upright)
		turn_world(rig, "FrontLeg_" + side, Vector3.RIGHT, .62 * upright)
		turn_world(rig, "BackUpLeg_" + side, Vector3.RIGHT, .21 * upright)
		turn_world(rig, "BackLeg_" + side, Vector3.RIGHT, -.27 * upright)
	var root_joint := rig.find_bone("Hips")
	var hips := rig.get_bone_global_pose(root_joint)
	var shift := anchor - (joint_world(rig, "BackPaw_L") + joint_world(rig, "BackPaw_R")) * .5
	shift.y = 0.0
	hips.origin += rig.global_basis.inverse() * shift
	rig.set_bone_global_pose(root_joint, hips)
	turn_world(rig, "Tail", Vector3.RIGHT, -.12 * pulse)

func pose_sheep(rig: Skeleton3D, phase: float, group: int) -> void:
	var breath := sin(TAU * phase)
	var look := sin(PI * phase) if group == 26 else 0.0
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .027 * breath + .05 * look)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .21 * look)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .22 * look + .033 * breath)
	turn_world(rig, "bip01 head", Vector3.UP, -.25 * look)
	turn_world(rig, "bip01 ponytail1", Vector3.BACK, .12 * breath + .15 * look)
	turn_world(rig, "bip01 ponytail2", Vector3.BACK, -.08 * breath + .11 * look)
	turn_world(rig, "bip01 tail", Vector3.UP, .10 * look)

func pose_stag(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := sin(PI * phase)
	if group == 26:
		turn_world(rig, "bip01 neck", Vector3.RIGHT, .28 * pulse)
		turn_world(rig, "bip01 neck1", Vector3.UP, -.39 * pulse)
		turn_world(rig, "bip01 head", Vector3.UP, -.23 * pulse)
	elif group == 27:
		var paw := smoothstep(.10, .58, phase) * (1.0 - smoothstep(.68, .95, phase))
		turn_world(rig, "bip01 neck", Vector3.RIGHT, .18 * pulse)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -.40 * paw)
		turn_world(rig, "bip01 l forearm", Vector3.RIGHT, .68 * paw)
	else:
		pose_doe(rig, phase, group)
		if group == 4:
			turn_world(rig, "bip01 neck1", Vector3.RIGHT, .11 * pulse)
