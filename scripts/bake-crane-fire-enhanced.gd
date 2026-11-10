# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const CraneFireStage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/crane-fire/"
const Aim := preload("res://Presentation/ElementalClassicGestures.gd")
const CraneClips := {4: "CraneWingThrust", 15: "CraneFanWarning", 25: "CraneQuietStand",
	26: "CraneBeakSweep", 27: "CraneWingBeat", 28: "CraneUnfurl"}
const CraneLengths := {4: .66, 15: .76, 25: .94, 26: 1.11, 27: 1.04, 28: .62}
const CraneJoints := ["bip01", "bip01 spine", "bip01 neck", "bip01 neck1", "bip01 neck2", "bip01 head",
	"bip01 tail", "l_wing_bone", "l_wing_bone01", "r_wing_bone", "r_wing_bone01"]
const FireClips := {23: "FireKindleAndRise", 28: "FireCrownAlert"}
const FireLengths := {23: .92, 28: .65}
const FireJoints := ["root", "pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "Head",
	"clavicle_l", "upperarm_l", "lowerarm_l", "hand_l", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]


func run() -> void:
	for body: int in [254, 15]:
		var row := Registry.entry(body)
		for treatment: String in row.assets:
			bake_candidate(body, treatment, row)
	quit()


func bake_candidate(body: int, treatment: String, row: Dictionary) -> void:
	var path := Registry.asset_path(row, treatment)
	var expected: String = row.asset_sha256[treatment] if row.asset_sha256 is Dictionary else row.asset_sha256
	assert(FileAccess.get_sha256(path) == expected)
	var model := (load(path) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var skins: Array[Dictionary] = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			skins.append(Ground.skin_points(mesh, rig))
	var clips := CraneClips if body == 254 else FireClips
	for group: int in clips:
		var motion: Animation
		if body == 254:
			motion = fit_grounded(player, rig, skins, CraneLengths[group], "bip01", CraneJoints,
				pose_crane.bind(group), .004)
		else:
			motion = fit_grounded(player, rig, skins, FireLengths[group], "root", FireJoints,
				pose_fire.bind(group), .005)
			if group == 23:
				fit_ignition(motion, player, rig)
		assert(library.add_animation(clips[group], motion) == OK)
	verify_base_clips(player, path)
	player.stop()
	rig.reset_bone_poses()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	assert(ResourceSaver.save(packed, CraneFireStage + "%d-%s.scn" % [body, treatment], ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()
	print("CRANE AND FIRE ENHANCED ", body, "/", treatment, ": ", clips.size(), " fitted gestures")


func pose_crane(rig: Skeleton3D, phase: float, group: int) -> void:
	var reach := 0.0
	var dip := 0.0
	var look := 0.0
	var open := 0.0
	var stroke := 0.0
	var bank := 0.0
	var fan := 0.0
	match group:
		4:
			reach = envelope(phase, .10, .39, .58, .94)
			open = envelope(phase, .02, .28, .63, 1.0)
			stroke = sin(TAU * (phase * 1.13 - .21)) * open
			bank = .26 * reach
		15:
			open = envelope(phase, .0, .24, .78, 1.0)
			stroke = sin(TAU * (phase * 1.30 - .08)) * .47 * open
			fan = envelope(phase, .12, .33, .72, .95)
			dip = .22 * fan
		25:
			reach = .038 * sin(TAU * phase)
			dip = .019 * sin(TAU * phase)
		26:
			dip = -.62 * envelope(phase, .03, .22, .39, .65) + .81 * smoothstep(.53, .95, phase)
			look = .45 * sin(TAU * phase) * sin(PI * phase)
		27:
			open = envelope(phase, .0, .16, .89, 1.0)
			stroke = sin(TAU * (phase * 1.82 + .20)) * .87 * open
			bank = .24 * sin(TAU * phase) * open
			dip = -.24 * open
		28:
			open = smoothstep(.10, .84, phase)
			stroke = .68 * open
			bank = .20 * open
			dip = -.21 * open
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .18 * reach + .11 * dip)
	turn_world(rig, "bip01 spine", Vector3.BACK, bank)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .46 * reach + .39 * dip)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .32 * reach + .58 * dip)
	turn_world(rig, "bip01 neck2", Vector3.RIGHT, .22 * reach + .36 * dip)
	turn_world(rig, "bip01 neck2", Vector3.UP, .56 * look)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.55 * reach + .30 * dip)
	turn_world(rig, "bip01 head", Vector3.UP, .65 * look)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.17 * open + .09 * reach)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var wing := side + "_wing_bone"
		var outer := wing + "01"
		# The original outer feathers point down in the folded rest pose.
		turn_world(rig, wing, Vector3.BACK, sign_x * (.88 * stroke - .77 * open))
		turn_world(rig, wing, Vector3.UP, -sign_x * (.16 * open + .46 * fan))
		turn_world(rig, outer, Vector3.BACK, sign_x * (1.58 * open - .26 * stroke))
		turn_world(rig, outer, Vector3.UP, -sign_x * (.13 * open + .25 * fan))


func pose_fire(rig: Skeleton3D, phase: float, group: int) -> void:
	var rise := smoothstep(.12, .76, phase)
	var fold := 1.0 - rise if group == 23 else 0.0
	var raise := .38 * rise if group == 23 else smoothstep(.10, .77, phase)
	turn_world(rig, "spine_01", Vector3.RIGHT, .33 * fold - .14 * raise)
	turn_world(rig, "spine_02", Vector3.RIGHT, .32 * fold)
	turn_world(rig, "spine_03", Vector3.BACK, .14 * sin(TAU * phase) * raise)
	turn_world(rig, "Head", Vector3.RIGHT, -.21 * fold - .23 * raise)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var upper := rig.find_bone("upperarm_" + side)
		var elbow := rig.find_bone("lowerarm_" + side)
		var hand := rig.find_bone("hand_" + side)
		Aim.aim(rig, upper, elbow, Vector3(-sign_x * .36, -.80, .40), fold)
		Aim.aim(rig, elbow, hand, Vector3(-sign_x * .56, -.20, .50), fold)
		Aim.aim(rig, upper, elbow, Vector3(sign_x * .68, .68, .33), raise)
		Aim.aim(rig, elbow, hand, Vector3(sign_x * .18, .94, .28), raise)


func fit_ignition(motion: Animation, player: AnimationPlayer, rig: Skeleton3D) -> void:
	var root_track := NodePath("%s:root" % player.get_node(player.root_node).get_path_to(rig))
	var scale := motion.find_track(root_track, Animation.TYPE_SCALE_3D)
	if scale < 0:
		scale = motion.add_track(Animation.TYPE_SCALE_3D)
		motion.track_set_path(scale, root_track)
	else:
		motion.track_remove_key(scale, 0)
	for frame in 81:
		var phase := float(frame) / 80.0
		var radius := lerpf(.27, 1.0, smoothstep(.10, .83, phase))
		var height := lerpf(.065, 1.0, smoothstep(.05, .76, phase))
		motion.scale_track_insert_key(scale, phase * motion.length, Vector3(radius, height, radius))
