# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Body := 241
const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/oni-enhanced/"
const Clips := {1: "OniCombatRest", 4: "OniSweepingClaw", 5: "OniDoubleClaw", 10: "OniRecoil",
	11: "OniLowSearch", 12: "OniFlameCast", 15: "OniRaisedGuard", 23: "OniCrouchedRise",
	25: "OniQuietRest", 26: "OniNearWatch", 28: "OniLowReady"}
const Times := {1: 1.14, 4: .70, 5: .75, 10: .68, 11: 1.24, 12: .98, 15: .75,
	23: 1.04, 25: 1.25, 26: 1.35, 28: .60}
const PoseJoints := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bone01", "bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 l finger0",
	"bip01 r upperarm", "bip01 r forearm", "bip01 r hand", "bip01 r finger0",
	"bip01 l thigh", "bip01 l calf", "bip01 l foot", "bip01 r thigh", "bip01 r calf", "bip01 r foot"]
const WalkJoints := ["bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm"]
const PeaceWalk := "OniPeaceWalk"


func run() -> void:
	var row := Registry.entry(Body)
	prepare_body(Body, Clips, Times, PoseJoints, pose_oni, Destination, mark_loop)
	for treatment: String in row.assets:
		var path := Destination + "%d-%s.scn" % [Body, treatment]
		var model := (ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var motion := peace_walk(player, rig)
		assert(player.get_animation_library("").add_animation(PeaceWalk, motion) == OK)
		verify_base_clips(player, Registry.asset_path(row, treatment))
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("ONI FITTED ", treatment, " ", Clips.size() + 1, " motions / ", FileAccess.get_sha256(path))
	quit()


func mark_loop(clip: Animation, _rig: Skeleton3D, group: int) -> void:
	if group in [1, 25]:
		clip.loop_mode = Animation.LOOP_LINEAR


func pose_oni(rig: Skeleton3D, phase: float, group: int) -> void:
	var windup := 0.0
	var reach := 0.0
	var crouch := 0.0
	var turn := 0.0
	var side_step := 0.0
	var broad := 0.0
	var look := 0.0
	match group:
		1:
			crouch = .11 + .038 * (1.0 - cos(TAU * phase))
			turn = .07 * sin(TAU * phase)
		4:
			windup = envelope(phase, .02, .22, .36, .57)
			reach = envelope(phase, .27, .53, .70, .98)
			turn = -.55 * windup + .89 * reach
			crouch = .44 * reach
			side_step = .74 * reach
			broad = .67 * maxf(windup, reach)
		5:
			windup = envelope(phase, .0, .28, .37, .57)
			reach = envelope(phase, .30, .58, .69, .99)
			crouch = .68 * reach
			side_step = .46 * reach
			broad = .45 * windup
		10:
			windup = .45 * envelope(phase, .01, .21, .37, .93)
			crouch = -.67 * windup
			turn = .38 * windup
			broad = .66 * windup
		11:
			crouch = .70 * envelope(phase, .03, .27, .78, .99)
			look = .61 * sin(TAU * 1.35 * phase) * crouch
			reach = .29 * crouch
		12:
			windup = .69 * envelope(phase, .02, .25, .40, .62)
			reach = envelope(phase, .37, .55, .79, .99)
			crouch = .41 * windup + .33 * reach
			turn = -.60 * windup + .49 * reach
			side_step = .29 * reach
			broad = .44 * windup
		15:
			windup = .78 * envelope(phase, .0, .24, .68, .98)
			crouch = .35 * windup
			broad = .23 * windup
		23:
			crouch = .86 * (1.0 - smoothstep(.19, .94, phase))
			reach = .42 * crouch
			look = -.28 * crouch
		25:
			crouch = .044 * (1.0 - cos(TAU * phase))
			look = .16 * sin(TAU * phase)
		26:
			look = .52 * envelope(phase, .06, .38, .69, .98)
			turn = .31 * look
			broad = .30 * look
		28:
			crouch = .22 + .32 * smoothstep(.10, .82, phase)
			reach = .32 * crouch
			broad = .23 * crouch
	var feet: Array[Transform3D] = []
	for side: String in ["l", "r"]:
		var foot := rig.get_bone_global_pose(rig.find_bone("bip01 %s foot" % side))
		var sign_x := 1.0 if side == "l" else -1.0
		foot.origin += rig.global_basis.inverse() * Vector3(sign_x * .23 * side_step,
			.23 * side_step if side == "r" else 0.0, .18 * sign_x * side_step)
		feet.append(foot)
	var pelvis := rig.find_bone("bip01 pelvis")
	var hips := rig.get_bone_global_pose(pelvis)
	hips.origin += rig.global_basis.inverse() * Vector3(.15 * turn, -.28 * crouch + .07 * windup, .16 * reach)
	rig.set_bone_global_pose(pelvis, hips)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .32 * crouch - .12 * windup)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .36 * crouch - .15 * windup)
	turn_world(rig, "bip01 spine1", Vector3.UP, .46 * turn)
	turn_world(rig, "bip01 spine2", Vector3.UP, .48 * turn)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.27 * crouch - .10 * windup)
	turn_world(rig, "bip01 head", Vector3.UP, .80 * look)
	turn_world(rig, "bone01", Vector3.RIGHT, -.20 * maxf(reach, windup))
	fit_foot(rig, "l", feet[0])
	fit_foot(rig, "r", feet[1])
	var chest := joint_world(rig, "bip01 spine2")
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var hand := joint_world(rig, "bip01 %s hand" % side)
		var high := chest + Vector3(sign_x * (.72 + .45 * broad), .79 + .39 * sign_x * turn, .28)
		var low := chest + Vector3(sign_x * (.56 + .62 * broad), -.40 + .37 * sign_x * turn, 1.11)
		var thrust := reach
		if group == 4:
			high.y += .65 if side == "l" else .20
			if side == "r":
				low.z -= .45
		if group == 5:
			high.y += .63
		if group == 12:
			if side == "r":
				low = chest + Vector3(-.69, -.14, 1.16)
			else:
				thrust *= .27
		if group == 15:
			high = chest + Vector3(sign_x * .68, .59, .76)
		if group == 10:
			high = chest + Vector3(sign_x * 1.10, .15, .38)
		if group == 11:
			low.y += .22 * sign_x * look
		var target := hand.lerp(high, windup).lerp(low, thrust)
		aim_oni_arm(rig, side, target, sign_x)
		turn_world(rig, "bip01 %s finger0" % side, Vector3.RIGHT, -.31 * thrust)


func aim_oni_arm(rig: Skeleton3D, side: String, target: Vector3, sign_x: float) -> void:
	var upper := rig.find_bone("bip01 %s upperarm" % side)
	var elbow := rig.find_bone("bip01 %s forearm" % side)
	var wrist := rig.find_bone("bip01 %s hand" % side)
	var start := rig.get_bone_global_pose(upper).origin
	var middle := rig.get_bone_global_pose(elbow).origin
	var end := rig.get_bone_global_pose(wrist).origin
	var goal := rig.to_local(target)
	if end.distance_squared_to(goal) < .000001:
		return
	var arm := start.distance_to(middle)
	var forearm := middle.distance_to(end)
	var axis := (goal - start).normalized()
	var length := clampf(start.distance_to(goal), absf(arm - forearm) + .01, arm + forearm - .01)
	var reach := (arm * arm - forearm * forearm + length * length) / (2.0 * length)
	var bend := (rig.global_basis.inverse() * Vector3(sign_x, -.33, .18)).slide(axis).normalized()
	var pivot := start + axis * reach + bend * sqrt(maxf(0.0, arm * arm - reach * reach))
	Arms.aim(rig, upper, elbow, pivot)
	rig.force_update_all_bone_transforms()
	Arms.aim(rig, elbow, wrist, goal)
	rig.force_update_all_bone_transforms()


func peace_walk(player: AnimationPlayer, rig: Skeleton3D) -> Animation:
	var motion := player.get_animation("Walk").duplicate(true) as Animation
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var tracks := {}
	for joint: String in WalkJoints:
		var path := NodePath("%s:%s" % [rig_path, joint])
		var track := motion.find_track(path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(track, path)
		else:
			for key in range(motion.track_get_key_count(track) - 1, -1, -1):
				motion.track_remove_key(track, key)
		tracks[rig.find_bone(joint)] = track
	player.play("Walk")
	player.advance(0.0)
	for index in 65:
		var phase := float(index) / 64.0
		var time := motion.length * phase
		rig.reset_bone_poses()
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, -.12)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -.09 + .035 * sin(TAU * phase))
		for side: String in ["l", "r"]:
			var sign_x := 1.0 if side == "l" else -1.0
			turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, -.12 * sign_x)
			turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, .11 * sin(TAU * phase) * sign_x)
		for bone: int in tracks:
			motion.rotation_track_insert_key(tracks[bone], time, rig.get_bone_pose_rotation(bone))
	motion.loop_mode = Animation.LOOP_LINEAR
	return motion
