# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/efreet-terathan-avenger/"
const Clips := {23: "EfreetLampArrival", 26: "EfreetCarpetBalance", 27: "EfreetCarpetSalute", 28: "EfreetCarpetWatch"}
const Lengths := {23: 1.56, 26: 1.18, 27: 1.26, 28: 1.12}
const Torso := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head"]


func run() -> void:
	var joints := Torso.duplicate()
	for side: String in ["l", "r"]:
		for joint: String in ["clavicle", "upperarm", "forearm", "hand", "thigh", "calf", "foot"]:
			joints.append("bip01 %s %s" % [side, joint])
	prepare_body(131, Clips, Lengths, joints, pose_efreet, Destination, set_hover_track)
	quit()


func pose_efreet(rig: Skeleton3D, phase: float, group: int) -> void:
	var curl := 0.0
	var open_arms := 0.0
	var lean := 0.0
	var look := 0.0
	match group:
		23:
			curl = 1.0 - smoothstep(.20, .74, phase)
			open_arms = .65 * envelope(phase, .30, .56, .66, .96)
			look = -.34 * envelope(phase, .17, .43, .52, .74)
		26:
			lean = -.21 * sin(TAU * phase) * sin(PI * phase)
			look = .24 * sin(TAU * phase)
		27:
			open_arms = envelope(phase, .06, .38, .68, .95)
			lean = .10 * sin(TAU * phase)
		28:
			look = .33 * envelope(phase, .10, .49, .69, .98)
			lean = .07 * sin(TAU * phase)
	turn_world(rig, "bip01 pelvis", Vector3.BACK, lean)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .21 * curl)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .35 * curl - .12 * open_arms)
	turn_world(rig, "bip01 spine2", Vector3.BACK, -.31 * lean)
	turn_world(rig, "bip01 head", Vector3.UP, look)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .30 * curl - .16 * open_arms)
	var chest := joint_world(rig, "bip01 spine2")
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.16 * curl)
		turn_world(rig, "bip01 %s calf" % side, Vector3.BACK, -.18 * curl * sign_x)
		var hand := joint_world(rig, "bip01 %s hand" % side)
		var gathered := chest + Vector3(sign_x * .18, -.14, .20)
		var raised := chest + Vector3(sign_x * (.75 - .18 * curl), .28 + .14 * sign_x * lean, .23)
		fit_arm(rig, side, hand.lerp(gathered, curl).lerp(raised, open_arms))
		turn_world(rig, "bip01 %s hand" % side, Vector3.BACK, sign_x * .42 * open_arms)


func set_hover_track(clip: Animation, rig: Skeleton3D, group: int) -> void:
	var rig_path := clip.track_get_path(0).get_concatenated_names()
	var pelvis_path := NodePath("%s:%s" % [rig_path, RootJoint])
	var track := clip.find_track(pelvis_path, Animation.TYPE_POSITION_3D)
	assert(track >= 0)
	var scale_track := -1
	if group == 23:
		var root_path := NodePath("%s:__root" % rig_path)
		scale_track = clip.find_track(root_path, Animation.TYPE_SCALE_3D)
		if scale_track < 0:
			scale_track = clip.add_track(Animation.TYPE_SCALE_3D)
			clip.track_set_path(scale_track, root_path)
	var parent := rig.get_bone_parent(rig.find_bone(RootJoint))
	var parent_frame := rig.global_basis * rig.get_bone_global_pose(parent).basis
	var up := parent_frame.inverse() * Vector3.UP
	for key in clip.track_get_key_count(track):
		var phase := clip.track_get_key_time(track, key) / clip.length
		var lift := .50 + .030 * sin(TAU * phase)
		if group == 23:
			lift = lerpf(.17, .50, smoothstep(.12, .86, phase)) + .055 * envelope(phase, .31, .51, .62, .78)
			var reveal := lerpf(.015, 1.0, smoothstep(.08, .63, phase))
			clip.scale_track_insert_key(scale_track, phase * clip.length, Vector3.ONE * reveal)
		var position: Vector3 = clip.track_get_key_value(track, key)
		clip.track_set_key_value(track, key, position + up * lift)
