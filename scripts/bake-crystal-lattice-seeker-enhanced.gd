# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Body := 123
const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/crystal-lattice-seeker-enhanced/"
const PeaceWalk := "LatticePeaceWalk"
const WalkJoints := ["bip01 spine2", "bip01 head", "box02", "box03", "box04", "box05", "box06", "box07"]
const Clips := {3: "Death2", 4: "LatticeRisingStrike", 5: "LatticeCrossingStrike", 10: "LatticeRecoil",
	11: "LatticeWingSearch", 12: "LatticeArcCast", 15: "LatticeWingCover", 23: "LatticeUnfurl",
	25: "LatticeQuietHover", 26: "LatticeNearGlance", 27: "LatticeBroadDisplay", 28: "LatticeHighWard"}
const Durations := {3: .95, 4: .87, 5: .91, 10: .51, 11: 1.16, 12: 1.22, 15: .61,
	23: 1.10, 25: 1.38, 26: .96, 27: 1.11, 28: 1.20}
const LatticeJoints := ["bip01 pelvis", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l clavicle", "bip01 r clavicle", "bip01 l upperarm", "bip01 r upperarm",
	"bip01 l forearm", "bip01 r forearm", "bip01 l hand", "bip01 r hand",
	"bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf", "bip01 l foot", "bip01 r foot",
	"box02", "box03", "box04", "box05", "box06", "box07"]


func run() -> void:
	prepare_body(Body, Clips, Durations, LatticeJoints, pose_lattice, Destination, finalize_lift)
	for treatment: String in Registry.entry(Body).assets:
		add_peace_walk(Destination + "%d-%s.scn" % [Body, treatment])
	quit()


func pose_lattice(rig: Skeleton3D, phase: float, group: int) -> void:
	if group == 3:
		pose_forward_fall(rig, phase)
		return
	var fold := 0.0
	var stroke := 0.0
	var brace := 0.0
	var ready := 0.0
	var reach := 0.0
	var turn := 0.0
	var lead := -1.0
	match group:
		4:
			ready = envelope(phase, .05, .28, .43, .67)
			reach = envelope(phase, .37, .62, .76, .98)
			stroke = .66 * ready - .71 * reach
			turn = .34 * ready - .56 * reach
			brace = .32 * reach
		5:
			ready = .80 * envelope(phase, .08, .37, .63, .85)
			reach = .84 * envelope(phase, .31, .59, .74, .99)
			stroke = -.35 * ready + .45 * reach
			turn = -.46 * ready + .48 * reach
			brace = .39 * reach
			lead = 1.0
		10:
			brace = -.72 * envelope(phase, 0.0, .22, .42, .94)
			fold = .39 * -brace
			stroke = .58 * -brace
			turn = .35 * brace
		11:
			brace = .53 * envelope(phase, .05, .33, .68, .97)
			fold = .39 * brace
			turn = .57 * sin(TAU * phase) * brace
			stroke = -.32 * brace
		12:
			fold = .93 * envelope(phase, 0.0, .20, .35, .55)
			stroke = .58 * fold - .66 * envelope(phase, .39, .63, .75, .99)
			ready = .88 * envelope(phase, .09, .37, .48, .68)
			reach = .95 * envelope(phase, .39, .57, .75, .98)
			brace = .50 * fold - .28 * reach
			turn = -.47 * reach
		15:
			fold = .78 * envelope(phase, .02, .27, .62, .97)
			stroke = -.51 * fold
			brace = .65 * fold
			ready = .51 * fold
		23:
			fold = .96 * (1.0 - smoothstep(.10, .43, phase))
			var open := envelope(phase, .16, .43, .57, .97)
			stroke = .34 * fold + .78 * open * cos(TAU * (phase - .30))
			brace = .87 * fold - .24 * open
			reach = .63 * open
		25:
			stroke = .022 * sin(TAU * phase)
			brace = .031 * sin(TAU * phase + .22)
			fold = .024
		26:
			var look := envelope(phase, .03, .39, .63, .96)
			turn = -.48 * look
			fold = .31 * look
			stroke = .12 * look * sin(TAU * phase)
		27:
			var display := envelope(phase, .04, .35, .72, .98)
			fold = -.46 * display
			stroke = .59 * display
			ready = .35 * display
			turn = .21 * display * sin(TAU * phase)
		28:
			ready = .79 * envelope(phase, .13, .39, .63, .86)
			reach = .67 * envelope(phase, .48, .68, .85, .99)
			stroke = .53 * ready - .67 * reach
			fold = -.46 * (ready + .33 * reach)
			brace = .21 * ready
	turn_world(rig, RootJoint, Vector3.RIGHT, .24 * brace)
	turn_world(rig, RootJoint, Vector3.FORWARD, .14 * turn)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .53 * brace - .18 * ready)
	turn_world(rig, "bip01 spine2", Vector3.UP, .70 * turn)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.28 * brace)
	turn_world(rig, "bip01 head", Vector3.UP, .39 * turn)
	for side: String in ["l", "r"]:
		var signum := 1.0 if side == "l" else -1.0
		var side_strength := 1.0 if signum == lead or group in [15, 23, 27, 28] else .38
		var fold_chain: Array = ["box02", "box03", "box04"] if side == "l" else ["box05", "box06", "box07"]
		turn_world(rig, fold_chain[0], Vector3.UP, -signum * (1.10 * fold - .18 * reach))
		turn_world(rig, fold_chain[0], Vector3.FORWARD, signum * (.83 * stroke + .35 * fold))
		turn_world(rig, fold_chain[1], Vector3.FORWARD, signum * (.43 * stroke - .28 * fold))
		turn_world(rig, fold_chain[1], Vector3.UP, -signum * .41 * fold)
		turn_world(rig, fold_chain[2], Vector3.UP, -signum * (.37 * fold - .16 * stroke))
		turn_world(rig, fold_chain[2], Vector3.RIGHT, .29 * stroke)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -side_strength * (1.19 * ready + .89 * reach))
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, signum * (.48 * reach - .17 * brace))
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -side_strength * (.55 * ready - .34 * reach))
		turn_world(rig, "bip01 %s hand" % side, Vector3.UP, -signum * (.20 * ready + .34 * reach))
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.71 * brace - .24 * ready)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .97 * brace + .36 * ready)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.31 * brace)


func finalize_lift(motion: Animation, rig: Skeleton3D, group: int) -> void:
	var lift := .29 if group == 23 else .17 if group in [4, 5, 12, 28] else 0.0
	if group == 25:
		motion.loop_mode = Animation.LOOP_LINEAR
	if lift <= 0.0:
		return
	var pelvis := rig.find_bone(RootJoint)
	var parent_basis := rig.get_bone_global_pose(rig.get_bone_parent(pelvis)).basis
	var up := parent_basis.inverse() * (rig.global_basis.inverse() * Vector3.UP)
	for track in motion.get_track_count():
		if motion.track_get_type(track) != Animation.TYPE_POSITION_3D or not str(motion.track_get_path(track)).ends_with(":" + RootJoint):
			continue
		for key in motion.track_get_key_count(track):
			var phase := motion.track_get_key_time(track, key) / motion.length
			var position: Vector3 = motion.track_get_key_value(track, key)
			motion.track_set_key_value(track, key, position + up * lift * envelope(phase, .12, .40, .62, .95))
		return
	assert(false, "Missing Lattice pelvis placement")



func pose_forward_fall(rig: Skeleton3D, phase: float) -> void:
	var pitch := smoothstep(.13, .69, phase)
	var flare := envelope(phase, .0, .22, .43, .76)
	var snap := envelope(phase, .37, .59, .75, .95)
	var settle := smoothstep(.63, .98, phase)
	turn_world(rig, RootJoint, Vector3.RIGHT, -.23 * flare + 1.47 * pitch)
	turn_world(rig, RootJoint, Vector3.FORWARD, -.24 * pitch + .15 * settle)
	turn_world(rig, RootJoint, Vector3.UP, -.29 * pitch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .31 * snap - .16 * settle)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.32 * flare - .25 * snap)
	turn_world(rig, "bip01 head", Vector3.UP, .19 * settle)
	for side: String in ["l", "r"]:
		var signum := 1.0 if side == "l" else -1.0
		var chain: Array = ["box02", "box03", "box04"] if side == "l" else ["box05", "box06", "box07"]
		turn_world(rig, chain[0], Vector3.FORWARD, signum * (.48 * flare - .58 * pitch))
		turn_world(rig, chain[0], Vector3.RIGHT, -.49 * snap + .52 * settle)
		turn_world(rig, chain[1], Vector3.UP, signum * (.22 * flare - .34 * settle))
		turn_world(rig, chain[1], Vector3.FORWARD, signum * (.24 * snap - .28 * settle))
		turn_world(rig, chain[2], Vector3.UP, -.26 * signum * settle)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.52 * snap - .24 * pitch)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, .76 * signum * pitch)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -.33 * flare + .36 * settle)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.33 * snap - .20 * signum * pitch)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .60 * snap + .20 * settle)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, .15 * pitch)
	var hip := rig.find_bone(RootJoint)
	var placement := rig.get_bone_global_pose(hip)
	placement.origin += rig.global_basis.inverse() * (Vector3.BACK * (.35 * pitch + .12 * settle) + Vector3.RIGHT * .14 * pitch)
	rig.set_bone_global_pose(hip, placement)


func add_peace_walk(path: String) -> void:
	var packed := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var model := packed.instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var walk := player.get_animation("Walk").duplicate(true) as Animation
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var tracks := {}
	for name: String in WalkJoints:
		var bone := rig.find_bone(name)
		assert(bone >= 0)
		var rotation := NodePath("%s:%s" % [rig_path, name])
		var track := walk.find_track(rotation, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = walk.add_track(Animation.TYPE_ROTATION_3D)
			walk.track_set_path(track, rotation)
		else:
			for key in range(walk.track_get_key_count(track) - 1, -1, -1):
				walk.track_remove_key(track, key)
		tracks[bone] = track
	player.play("Walk")
	player.advance(0.0)
	for frame in 65:
		var phase := float(frame) / 64.0
		var time := phase * walk.length
		rig.reset_bone_poses()
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		shape_peace_walk(rig, phase)
		for bone: int in tracks:
			walk.rotation_track_insert_key(tracks[bone], time, rig.get_bone_pose_rotation(bone))
	walk.loop_mode = Animation.LOOP_LINEAR
	assert(player.get_animation_library("").add_animation(PeaceWalk, walk) == OK)
	player.stop()
	rig.reset_bone_poses()
	packed = PackedScene.new()
	assert(packed.pack(model) == OK and ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()


func shape_peace_walk(rig: Skeleton3D, phase: float) -> void:
	var sway := sin(phase * TAU)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, -.17)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.064)
	for side in [1, -1]:
		var chain: Array = ["box02", "box03", "box04"] if side == 1 else ["box05", "box06", "box07"]
		turn_world(rig, chain[0], Vector3.UP, side * (.18 + .03 * sway))
		turn_world(rig, chain[0], Vector3.FORWARD, side * (-.12 + .05 * sway))
		turn_world(rig, chain[1], Vector3.FORWARD, side * (.25 + .05 * sway))
		turn_world(rig, chain[2], Vector3.RIGHT, .095 * sway)
