# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Sculpt := preload("orc-brute-body-sculpt.gd")
const Body := 189
const Hip := "bip_01"
const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/orc-brute-enhanced/"
const Clips := {1: "BruteCombatRest", 3: "Death2", 4: "BruteDoubleHammer", 5: "BruteTurningSweep",
	10: "BruteRecoil", 11: "BruteLowRummage", 15: "BruteForearmGuard", 23: "BruteCrouchedRise",
	25: "BruteQuietRest", 26: "BruteNearWatch", 27: "BruteOverheadThreat", 28: "BruteLowReady"}
const Times := {1: 1.14, 3: 1.1, 4: .96, 5: .91, 10: .67, 11: 1.19, 15: .69,
	23: 1.04, 25: 1.37, 26: .94, 27: 1.14, 28: .64}
const Trunk := [Hip, "bip_01 pelvis", "bip_01 spine", "bip_01 spine1", "bip_01 spine2",
	"bip_01 spine3", "bip_01 neck", "bip_01 head"]
const Limbs := ["clavicle", "upperarm", "forearm", "hand", "finger0", "finger01",
	"finger1", "finger11", "thigh", "calf", "foot", "toe0"]
const PeaceWalk := "BrutePeaceWalk"
const WalkJoints := ["bip_01 spine2", "bip_01 spine3", "bip_01 neck", "bip_01 head",
	"bip_01 l upperarm", "bip_01 r upperarm", "bip_01 l forearm", "bip_01 r forearm"]


func run() -> void:
	var row := Registry.entry(Body)
	var joints := Trunk.duplicate()
	for side: String in ["l", "r"]:
		for limb: String in Limbs:
			joints.append("bip_01 %s %s" % [side, limb])
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var sculpted := "--brute-silhouette" in OS.get_cmdline_user_args()
		if sculpted:
			var body := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			Sculpt.shape(body, rig)
		var skins: Array[Dictionary] = []
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			skins.append(Ground.skin_points(mesh, rig))
		for group: int in Clips:
			var clip := fit_grounded(player, rig, skins, Times[group], Hip, joints, pose_brute.bind(group), .004)
			if group in [1, 25]:
				clip.loop_mode = Animation.LOOP_LINEAR
			assert(library.add_animation(Clips[group], clip) == OK)
		assert(library.add_animation(PeaceWalk, quiet_walk(player, rig)) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var packed := PackedScene.new()
		assert(packed.pack(model) == OK)
		var folder := Destination + "silhouette/" if sculpted else Destination
		assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) == OK)
		var path := folder + "%d-%s.scn" % [Body, treatment]
		assert(ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("ORC BRUTE FITTED ", treatment, ": ", Clips.size() + 1, " motions / ", FileAccess.get_sha256(path))
	quit()


func pose_brute(rig: Skeleton3D, phase: float, group: int) -> void:
	if group == 3:
		pose_fall(rig, phase)
		return
	var crouch := 0.0
	var high := 0.0
	var strike := 0.0
	var turn := 0.0
	var step := 0.0
	var spread := 0.0
	var scan := 0.0
	match group:
		1:
			crouch = .23 + .045 * (1.0 - cos(TAU * phase))
			turn = .08 * sin(TAU * phase)
		4:
			high = envelope(phase, .0, .23, .32, .54)
			strike = envelope(phase, .26, .52, .65, .97)
			crouch = .18 + .77 * strike
			spread = .37 * high
			step = .21 * strike
		5:
			high = .56 * envelope(phase, .03, .27, .41, .66)
			strike = envelope(phase, .24, .49, .59, .97)
			turn = -.48 * high + .86 * strike
			spread = .78 * strike
			step = .88 * envelope(phase, .10, .39, .63, .95)
			crouch = .33 * strike
		10:
			high = .49 * envelope(phase, .0, .17, .37, .92)
			turn = -.33 * high
			crouch = -.36 * high
		11:
			crouch = .67 * envelope(phase, .0, .19, .83, .99)
			strike = .31 * crouch
			scan = sin(TAU * 1.5 * phase) * crouch
		15:
			high = .74 * envelope(phase, .0, .21, .70, .98)
			crouch = .46 * high
			turn = -.40 * high
		23:
			crouch = 1.0 - smoothstep(.21, .91, phase)
			strike = .44 * crouch
		25:
			crouch = .10 + .055 * (1.0 - cos(TAU * phase))
			scan = .18 * sin(TAU * phase)
		26:
			scan = .53 * envelope(phase, .04, .38, .65, .98)
			crouch = .24 * scan
			turn = .18 * scan
		27:
			high = envelope(phase, .0, .24, .31, .49)
			strike = .65 * envelope(phase, .28, .48, .65, 1.0)
			crouch = .67 * strike
			spread = .49 * high + .51 * strike
			step = .69 * envelope(phase, .04, .24, .44, .80)
		28:
			crouch = .22 + .26 * smoothstep(.05, .69, phase)
			strike = .35 * crouch
			spread = .42 * crouch
			turn = -.16 * crouch
	var feet: Array[Transform3D] = []
	for side: String in ["l", "r"]:
		var foot := rig.get_bone_global_pose(rig.find_bone("bip_01 %s foot" % side))
		if side == "r":
			foot.origin += rig.global_basis.inverse() * Vector3(-.16 * step, .20 * step, -.25 * step)
		feet.append(foot)
	shift_hip(rig, Vector3(-.10 * turn, -.34 * crouch + .08 * high, .10 * strike))
	turn_world(rig, Hip, Vector3.UP, .26 * turn)
	turn_world(rig, "bip_01 spine1", Vector3.RIGHT, .52 * crouch - .21 * high)
	turn_world(rig, "bip_01 spine2", Vector3.RIGHT, .43 * crouch - .14 * high)
	turn_world(rig, "bip_01 spine3", Vector3.UP, .52 * turn)
	turn_world(rig, "bip_01 head", Vector3.RIGHT, -.16 * crouch)
	turn_world(rig, "bip_01 head", Vector3.UP, scan * .71)
	fit_brute_foot(rig, "l", feet[0])
	fit_brute_foot(rig, "r", feet[1])
	var chest := joint_world(rig, "bip_01 spine2")
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		var hand := joint_world(rig, "bip_01 %s hand" % side)
		var high_target := chest + Vector3(sign_x * (.55 + .33 * spread), .54 + .13 * sign_x * turn, .53)
		var low_target := chest + Vector3(sign_x * (.46 + .43 * spread), -.45 + .24 * turn * sign_x, .85)
		if group == 5:
			low_target = chest + Vector3(-.10 + .78 * sign_x, .16 + .33 * sign_x, .75)
		if group == 11:
			low_target.y -= .25 * sign_x * scan
		if group == 10:
			high_target = chest + Vector3(sign_x * .85, .19, .39)
		if group == 15:
			high_target = chest + Vector3(sign_x * .55, .53 + .14 * sign_x, .72)
		var shape := hand.lerp(high_target, high).lerp(low_target, strike)
		if side == "r":
			var outside := 0.0
			match group:
				4: outside = .20 * envelope(phase, .01, .080, .14, .24)
				5: outside = .29 * envelope(phase, .02, .092, .23, .32)
				15: outside = .16 * (envelope(phase, .02, .075, .13, .22) + envelope(phase, .73, .81, .89, .97))
			shape.x -= outside
			shape.z += .28 * outside
		fit_brute_arm(rig, side, shape, sign_x)
		var fist := maxf(high * .64, strike * (.26 if group == 11 else .74))
		turn_world(rig, "bip_01 %s finger1" % side, Vector3.RIGHT, fist * -.48)
		turn_world(rig, "bip_01 %s finger11" % side, Vector3.RIGHT, fist * -.65)


func pose_fall(rig: Skeleton3D, phase: float) -> void:
	var fall := smoothstep(.19, .64, phase)
	var settle := smoothstep(.62, .89, phase)
	var recoil := envelope(phase, .02, .24, .38, .57)
	turn_world(rig, Hip, Vector3.RIGHT, -1.44 * fall - .15 * recoil)
	turn_world(rig, Hip, Vector3.FORWARD, -.18 * recoil + .10 * settle)
	turn_world(rig, "bip_01 spine1", Vector3.RIGHT, -.34 * recoil + .10 * settle)
	turn_world(rig, "bip_01 head", Vector3.RIGHT, .19 * settle)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip_01 %s upperarm" % side, Vector3.BACK, sign_x * (.44 * recoil + .61 * fall))
		turn_world(rig, "bip_01 %s forearm" % side, Vector3.RIGHT, -.62 * recoil + .17 * settle)
		turn_world(rig, "bip_01 %s thigh" % side, Vector3.RIGHT, -.41 * recoil - (.26 + .14 * sign_x) * fall)
		turn_world(rig, "bip_01 %s calf" % side, Vector3.RIGHT, .62 * recoil + .18 * fall)
	shift_hip(rig, Vector3(-.07 * fall, 0, -.66 * fall - .12 * settle))


func shift_hip(rig: Skeleton3D, offset: Vector3) -> void:
	var joint := rig.find_bone(Hip)
	var pose := rig.get_bone_global_pose(joint)
	pose.origin += rig.global_basis.inverse() * offset
	rig.set_bone_global_pose(joint, pose)
	rig.force_update_all_bone_transforms()


func fit_brute_arm(rig: Skeleton3D, side: String, target: Vector3, sign_x: float) -> void:
	var upper := rig.find_bone("bip_01 %s upperarm" % side)
	var forearm := rig.find_bone("bip_01 %s forearm" % side)
	var hand := rig.find_bone("bip_01 %s hand" % side)
	aim_chain(rig, upper, forearm, hand, rig.to_local(target), Vector3(sign_x, -.26, .19))


func fit_brute_foot(rig: Skeleton3D, side: String, target: Transform3D) -> void:
	var thigh := rig.find_bone("bip_01 %s thigh" % side)
	var calf := rig.find_bone("bip_01 %s calf" % side)
	var foot := rig.find_bone("bip_01 %s foot" % side)
	aim_chain(rig, thigh, calf, foot, target.origin, Vector3(.18 if side == "l" else -.18, 0.0, 1.0))
	target.origin = rig.get_bone_global_pose(foot).origin
	rig.set_bone_global_pose(foot, target)
	rig.force_update_all_bone_transforms()


func aim_chain(rig: Skeleton3D, base: int, pivot: int, tip: int, target: Vector3, bend_world: Vector3) -> void:
	var start := rig.get_bone_global_pose(base).origin
	var original_pivot := rig.get_bone_global_pose(pivot).origin
	var original_tip := rig.get_bone_global_pose(tip).origin
	if original_tip.distance_squared_to(target) < 0.000001:
		return
	var first := start.distance_to(original_pivot)
	var second := original_pivot.distance_to(original_tip)
	var axis := (target - start).normalized()
	var span := clampf(start.distance_to(target), absf(first - second) + .001, first + second - .001)
	var along := (first * first - second * second + span * span) / (2.0 * span)
	var bend := (rig.global_basis.inverse() * bend_world).slide(axis).normalized()
	var mid := start + axis * along + bend * sqrt(maxf(0.0, first * first - along * along))
	Arms.aim(rig, base, pivot, mid)
	rig.force_update_all_bone_transforms()
	Arms.aim(rig, pivot, tip, target)
	rig.force_update_all_bone_transforms()


func quiet_walk(player: AnimationPlayer, rig: Skeleton3D) -> Animation:
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
	for sample in 65:
		var phase := float(sample) / 64.0
		var time := motion.length * phase
		rig.reset_bone_poses()
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		turn_world(rig, "bip_01 spine2", Vector3.RIGHT, -.13)
		turn_world(rig, "bip_01 head", Vector3.RIGHT, -.08 + .043 * cos(TAU * phase))
		for side: String in ["l", "r"]:
			var sign_x := 1.0 if side == "l" else -1.0
			turn_world(rig, "bip_01 %s upperarm" % side, Vector3.BACK, -.11 * sign_x)
			turn_world(rig, "bip_01 %s forearm" % side, Vector3.RIGHT, .10 * sin(TAU * phase) * sign_x)
		for bone: int in tracks:
			motion.rotation_track_insert_key(tracks[bone], time, rig.get_bone_pose_rotation(bone))
	motion.loop_mode = Animation.LOOP_LINEAR
	return motion
