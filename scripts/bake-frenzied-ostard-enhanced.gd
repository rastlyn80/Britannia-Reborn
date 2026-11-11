# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/frenzied-ostard-enhanced/"
const Source := "res://local-art/ostards/frenzied-%s.gltf"
const Gestures := {4: "FrenziedOstardSnap", 15: "FrenziedOstardCoil", 23: "FrenziedOstardRise",
	25: "FrenziedOstardQuietIdle", 26: "FrenziedOstardTailCheck", 27: "FrenziedOstardHighAlert",
	28: "FrenziedOstardReady", 31: "FrenziedOstardSeatedIdle"}
const Durations := {4: .79, 15: .65, 23: 1.07, 25: 1.12, 26: 1.09, 27: .97, 28: .74, 31: 1.0}
const Gaits := {22: ["Walk", "FrenziedOstardPeaceWalk", .96], 29: ["Walk", "FrenziedOstardSeatedWalk", .90],
	30: ["Run", "FrenziedOstardSeatedRun", .78]}
const PoseJoints := ["bip01 spine", "bip01 spine1", "bip01 neck", "bip01 neck1", "bip01 neck2",
	"bip01 head", "bip01 ponytail1", "bip01 tail", "bip01 tail1", "bip01 l thigh", "bip01 r thigh",
	"bip01 l calf", "bip01 r calf"]
const GaitJoints := ["bip01 spine1", "bip01 neck", "bip01 neck1", "bip01 head", "bip01 tail", "bip01 tail1"]


func run() -> void:
	for treatment: String in ["original", "rounded", "modern"]:
		var path := Source % treatment
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh, rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		for group: int in Gestures:
			var clip := fit_grounded(player, rig, [skin], Durations[group], "bip01", PoseJoints, pose_ostard.bind(group), .004)
			if group in [25, 31]:
				clip.loop_mode = Animation.LOOP_LINEAR
			assert(library.add_animation(Gestures[group], clip) == OK)
		for group: int in Gaits:
			var row: Array = Gaits[group]
			var clip := fit_gait(player, rig, row[0], row[2], group)
			assert(library.add_animation(row[1], clip) == OK)
		verify_base_clips(player, path)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Destination + "218-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("FRENZIED OSTARD FIT ", treatment, ": eight gestures and three gait loops")
	quit()


func pose_ostard(rig: Skeleton3D, phase: float, group: int) -> void:
	var dip := 0.0
	var raise := 0.0
	var brace := 0.0
	var turn := 0.0
	var flick := 0.0
	match group:
		4:
			raise = .58 * envelope(phase, .01, .23, .35, .61)
			dip = envelope(phase, .35, .57, .72, 1.0)
			flick = -.49 * raise + .44 * dip
		15:
			raise = .72 * envelope(phase, .07, .30, .65, .96)
			brace = .59 * raise
			flick = .60 * raise
		23:
			dip = 1.0 - smoothstep(.13, .48, phase)
			raise = .92 * envelope(phase, .21, .63, .68, .98)
			brace = .41 * dip
			flick = .33 * raise - .26 * dip
		25:
			dip = .030 * sin(TAU * phase)
			flick = .047 * sin(TAU * phase)
		26:
			dip = .24 * envelope(phase, .10, .34, .61, .98)
			turn = .31 * sin(TAU * phase) * sin(PI * phase)
			flick = .58 * envelope(phase, .09, .31, .56, .99)
		27:
			dip = .44 * (1.0 - smoothstep(.04, .33, phase))
			raise = .94 * envelope(phase, .16, .46, .64, .93)
			flick = .53 * raise
		28:
			dip = .61 * smoothstep(.10, .74, phase)
			brace = .35 * dip
			turn = .23 * sin(PI * phase)
			flick = -.33 * dip
		31:
			dip = .13 + .04 * sin(TAU * phase)
			flick = .055 * sin(TAU * phase)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .14 * dip - .13 * raise)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .23 * dip - .18 * raise)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .34 * dip - .28 * raise)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .25 * dip - .28 * raise)
	turn_world(rig, "bip01 neck2", Vector3.RIGHT, .19 * dip - .25 * raise)
	turn_world(rig, "bip01 neck2", Vector3.UP, .52 * turn)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.20 * dip + .13 * raise)
	turn_world(rig, "bip01 head", Vector3.UP, .53 * turn)
	turn_world(rig, "bip01 ponytail1", Vector3.RIGHT, -.24 * flick)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.34 * flick)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, -.29 * flick)
	for side: String in ["l", "r"]:
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.17 * brace)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .21 * brace)


func fit_gait(player: AnimationPlayer, rig: Skeleton3D, seed: String, length: float, group: int) -> Animation:
	var source := player.get_animation(seed)
	var result := source.duplicate(true) as Animation
	var ratio := length / source.length
	result.length = length
	result.loop_mode = Animation.LOOP_LINEAR
	var path := player.get_node(player.root_node).get_path_to(rig)
	var editable := {}
	for joint: String in GaitJoints:
		var track_path := NodePath("%s:%s" % [path, joint])
		var track := result.find_track(track_path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = result.add_track(Animation.TYPE_ROTATION_3D)
			result.track_set_path(track, track_path)
		editable[track] = rig.find_bone(joint)
	for track in result.get_track_count():
		var count := result.track_get_key_count(track)
		if editable.has(track):
			for index in range(count - 1, -1, -1):
				result.track_remove_key(track, index)
		else:
			var indices := range(count - 1, -1, -1) if ratio > 1.0 else range(count)
			for index in indices:
				result.track_set_key_time(track, index, result.track_get_key_time(track, index) * ratio)
	player.play(seed, 0.0)
	player.advance(0.0)
	var source_loop := source.loop_mode
	source.loop_mode = Animation.LOOP_NONE
	for frame in 81:
		var phase := float(frame) / 80.0
		rig.reset_bone_poses()
		player.seek(source.length * phase, true)
		rig.force_update_all_bone_transforms()
		var stride := sin(TAU * phase)
		var mounted := group != 22
		var running := group == 30
		var reach := (.14 if running else .07) if mounted else -.04
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, reach * .28 + .016 * stride)
		turn_world(rig, "bip01 neck", Vector3.RIGHT, reach + .035 * stride)
		turn_world(rig, "bip01 neck1", Vector3.RIGHT, reach * .54 - .018 * stride)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -reach * .29)
		turn_world(rig, "bip01 tail", Vector3.RIGHT, -.23 * reach + .049 * stride)
		turn_world(rig, "bip01 tail1", Vector3.UP, (.095 if mounted else .052) * stride)
		for track: int in editable:
			result.rotation_track_insert_key(track, length * phase, rig.get_bone_pose_rotation(editable[track]))
	source.loop_mode = source_loop
	return result
