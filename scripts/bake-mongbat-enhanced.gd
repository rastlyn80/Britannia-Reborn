# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Folder := "res://../work/creatures/native-form-audit/enhanced-source-gaps/skeleton-mongbat/"
const BatClips := {4: "MongbatDivingSwoop", 23: "MongbatUnfoldAndRise", 26: "MongbatQuietHover",
	27: "MongbatHoverRebalance", 28: "MongbatWingAlert"}
const BatLengths := {4: .60, 23: .80, 26: 1.1, 27: .90, 28: .50}
const BatJoints := ["bip01", "bip01 spine", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 r upperarm", "bip01 r forearm",
	"bip01 l thigh", "bip01 l calf", "bip01 r thigh", "bip01 r calf", "bip01 tail", "bip01 tail1", "bip01 tail2"]
const WingJoints := ["mongbat l wingmain1", "mongbat l wingmain2", "mongbat l wingfinger1a", "mongbat l wingfinger2a",
	"mongbat l wingfinger3a", "mongbat l wingfinger1b", "mongbat l wingfinger2b", "mongbat l wingfinger3b",
	"mongbat r wingmain1", "mongbat r wingmain2", "mongbat r wingfinger1a", "mongbat r wingfinger2a",
	"mongbat r wingfinger3a", "mongbat r wingfinger1b", "mongbat r wingfinger2b", "mongbat r wingfinger3b"]
const FoldAxis := Vector3(0, .97, .24)

func run() -> void:
	var row := Registry.entry(39)
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
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
		var archive := archived_wings(player, rig)
		for group: int in BatClips:
			var clip := fit_grounded(player, rig, skins, BatLengths[group], "bip01", BatJoints + WingJoints,
				pose_bat.bind(group, archive), .004)
			add_air_path(clip, rig, player, group)
			assert(library.add_animation(BatClips[group], clip) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Folder + "39-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("MONGBAT ENHANCED ", treatment, ": five fitted wing/body motions, retained AirDeath and flight keys")
	quit()

func archived_wings(player: AnimationPlayer, rig: Skeleton3D) -> Array[Dictionary]:
	player.play("Fly", 0.0)
	player.advance(0.0)
	var poses: Array[Dictionary] = []
	for index in 21:
		player.seek(player.current_animation_length * float(index) / 20.0, true)
		rig.force_update_all_bone_transforms()
		var wings := {}
		for joint: String in WingJoints:
			wings[joint] = rig.get_bone_pose_rotation(rig.find_bone(joint))
		poses.append(wings)
	return poses

func blend_archived_wings(rig: Skeleton3D, archive: Array[Dictionary], at: float, weight: float) -> void:
	var time := at * float(archive.size() - 1)
	var index := mini(floori(time), archive.size() - 2)
	for joint: String in WingJoints:
		var bone := rig.find_bone(joint)
		var a: Quaternion = archive[index][joint]
		var b: Quaternion = archive[index + 1][joint]
		rig.set_bone_pose_rotation(bone, rig.get_bone_pose_rotation(bone).slerp(a.slerp(b, time - index), weight))
	rig.force_update_all_bone_transforms()

func pose_bat(rig: Skeleton3D, phase: float, group: int, archive: Array[Dictionary]) -> void:
	var beat := sin(TAU * phase)
	var pitch := 0.0
	var fold := 0.0
	var wing_stroke := 0.0
	var curl := 0.0
	var gather := 0.0
	var spread := .82
	var archive_time := .55 + .04 * beat
	match group:
		4:
			var dive := smoothstep(.22, .51, phase) * (1.0 - smoothstep(.58, .95, phase))
			pitch = .78 * dive
			fold = .20 * dive
			wing_stroke = -.19 * beat
			curl = -.39 * dive
			gather = .36 * dive
			spread = .90
			archive_time = lerpf(.72, .24, dive)
		23:
			var open := smoothstep(.23, .72, phase)
			fold = 1.18 * (1.0 - open)
			wing_stroke = -.27 * sin(TAU * open)
			pitch = .65 * (1.0 - open)
			curl = .83 * (1.0 - open)
			gather = .91 * (1.0 - open)
			spread = open
			archive_time = .69 - .17 * sin(PI * open)
		26:
			fold = .05 + .08 * sin(PI * phase)
			wing_stroke = .08 * beat
			curl = .16 * sin(PI * phase)
			gather = .23
			turn_world(rig, "bip01 head", Vector3.UP, -.20 * sin(PI * phase))
		27:
			var change := sin(PI * phase)
			fold = -.17 * change
			wing_stroke = .18 * beat
			pitch = -.18 * change
			curl = -.34 * change
			spread = .96
			archive_time = .54 + .15 * beat
		28:
			var ready := smoothstep(.06, .87, phase)
			fold = -.29 * ready
			wing_stroke = .16 * ready
			pitch = -.21 * ready
			gather = -.28 * ready
			curl = .22 * ready
			spread = .65 + .27 * ready
	blend_archived_wings(rig, archive, archive_time, spread)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, pitch * .65)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, pitch * .35)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.31 * pitch)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, curl * .52)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, curl * .63)
	turn_world(rig, "bip01 tail2", Vector3.UP, .18 * beat)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var wing := "mongbat " + side + " wing"
		for joint: String in ["main1", "main2"]:
			turn_world(rig, wing + joint, FoldAxis, sign_x * fold)
			turn_world(rig, wing + joint, Vector3.BACK, sign_x * wing_stroke)
		turn_world(rig, wing + "finger1a", FoldAxis, sign_x * fold * .17)
		turn_world(rig, wing + "finger2a", Vector3.BACK, sign_x * wing_stroke * .18)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.32 * gather)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.55 * gather)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.51 * gather)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .43 * gather)

func add_air_path(clip: Animation, rig: Skeleton3D, player: AnimationPlayer, group: int) -> void:
	var hip := rig.find_bone("bip01")
	var parent := rig.get_bone_parent(hip)
	var space := (rig.global_basis * rig.get_bone_global_pose(parent).basis).inverse()
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var track := clip.find_track(NodePath("%s:bip01" % rig_path), Animation.TYPE_POSITION_3D)
	assert(track >= 0)
	for key in clip.track_get_key_count(track):
		var phase := clip.track_get_key_time(track, key) / clip.length
		var beat := sin(PI * phase)
		var height := .16 + .09 * beat
		var forward := 0.0
		if group == 4:
			height = .32 - .24 * beat
			forward = .27 * beat * beat
		elif group == 23:
			height = .43 * smoothstep(.16, .77, phase)
		var point: Vector3 = clip.track_get_key_value(track, key)
		clip.track_set_key_value(track, key, point + space * Vector3(0, height, forward))
