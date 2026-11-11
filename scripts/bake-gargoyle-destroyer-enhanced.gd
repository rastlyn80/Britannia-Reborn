# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destroyer := 755
const Enforcer := 754
const GapFolder := "res://../work/creatures/native-form-audit/enhanced-source-gaps/"
const PeaceWalk := "GargoylePeaceWalk"
const WalkJoints := ["bip01 spine2", "bip01 head", "bip01 l upperarm", "bip01 r upperarm",
	"gargoyle l mainwing1", "gargoyle r mainwing1", "gargoyle l mainwing2", "gargoyle r mainwing2"]
const CommonClips := {3: "Death2", 4: "GargoyleWingRake", 5: "GargoyleDrivingPalms", 11: "GargoyleLowSearch",
	15: "GargoyleShieldingWings", 23: "GargoyleGroundRise", 25: "GargoyleQuietHover",
	26: "GargoyleNearGlance", 27: "GargoyleWingThreat", 28: "GargoyleGuardCrouch"}
const Lengths := {3: .99, 4: .87, 5: .96, 11: 1.09, 15: .79, 23: 1.12, 25: 1.25,
	26: .91, 27: 1.02, 28: .74, 31: .48, 32: .65}
const GargoyleJoints := ["bip01 pelvis", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l clavicle", "bip01 r clavicle", "bip01 l upperarm", "bip01 r upperarm",
	"bip01 l forearm", "bip01 r forearm", "bip01 l hand", "bip01 r hand", "bip01 l thigh",
	"bip01 r thigh", "bip01 l calf", "bip01 r calf", "bip01 l foot", "bip01 r foot",
	"gargoyle l mainwing1", "gargoyle r mainwing1", "gargoyle l mainwing2", "gargoyle r mainwing2",
	"gargoyle l wing3", "gargoyle r wing3"]


static func destination(body: int) -> String:
	return GapFolder + ("gargoyle-destroyer-enhanced/" if body == Destroyer else "gargoyle-enforcer-enhanced/")


static func clips(body: int) -> Dictionary:
	return CommonClips.merged({31: "DestroyerHatchetCounter"} if body == Destroyer else {32: "EnforcerTurningSweep"})


static func review_clips(body: int) -> Dictionary:
	return clips(body).merged({22: PeaceWalk})


func run() -> void:
	for body in [Destroyer, Enforcer]:
		prepare_body(body, clips(body), Lengths, GargoyleJoints, pose_gargoyle.bind(body), destination(body), finalize)
		for treatment: String in Registry.entry(body).assets:
			add_peace_walk(destination(body) + "%d-%s.scn" % [body, treatment])
	quit()


func add_peace_walk(path: String) -> void:
	var model := (ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var source := player.get_animation("Walk")
	var walk := source.duplicate(true) as Animation
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var tracks := {}
	for joint: String in WalkJoints:
		var joint_path := NodePath("%s:%s" % [rig_path, joint])
		var track := walk.find_track(joint_path, Animation.TYPE_ROTATION_3D)
		if track == -1:
			track = walk.add_track(Animation.TYPE_ROTATION_3D)
			walk.track_set_path(track, joint_path)
		for key in range(walk.track_get_key_count(track) - 1, -1, -1):
			walk.track_remove_key(track, key)
		tracks[joint] = track
	player.play("Walk")
	player.advance(0.0)
	for frame in 81:
		var phase := float(frame) / 80.0
		var time := phase * source.length
		rig.reset_bone_poses()
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		shape_peace_walk(rig, phase)
		for joint: String in tracks:
			walk.rotation_track_insert_key(tracks[joint], time, rig.get_bone_pose_rotation(rig.find_bone(joint)))
	walk.loop_mode = Animation.LOOP_LINEAR
	assert(player.get_animation_library("").add_animation(PeaceWalk, walk) == OK)
	player.stop()
	rig.reset_bone_poses()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	assert(ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()


func shape_peace_walk(rig: Skeleton3D, phase: float) -> void:
	var sway := sin(TAU * phase)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, -.13)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.065)
	for side: String in ["l", "r"]:
		var signum := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK, -.12 * signum)
		turn_world(rig, "gargoyle %s mainwing1" % side, Vector3.BACK, signum * .20 + .075 * sway)
		turn_world(rig, "gargoyle %s mainwing1" % side, Vector3.UP, signum * .16)
		turn_world(rig, "gargoyle %s mainwing2" % side, Vector3.RIGHT, -.14 + .045 * signum * sway)


func finalize(motion: Animation, _rig: Skeleton3D, group: int) -> void:
	if group == 25:
		motion.loop_mode = Animation.LOOP_LINEAR


func pose_gargoyle(rig: Skeleton3D, phase: float, group: int, body: int) -> void:
	if group == 3:
		pose_rolled_fall(rig, phase, body)
		return
	var raise_arm := 0.0
	var strike := 0.0
	var crouch := 0.0
	var turn := 0.0
	var wing_open := 0.0
	var lead := -1.0 if body == Destroyer else 1.0
	match group:
		4:
			raise_arm = envelope(phase, .04, .31, .42, .60)
			strike = envelope(phase, .28, .54, .72, .99)
			crouch = .66 * strike
			wing_open = .93 * strike - .24 * raise_arm
			turn = lead * (.44 * raise_arm - .49 * strike)
		5:
			raise_arm = .38 * envelope(phase, .03, .26, .42, .62)
			strike = envelope(phase, .29, .55, .72, .97)
			crouch = .76 * strike
			wing_open = .88 * strike
			turn = lead * (.19 * raise_arm + .38 * strike)
		11:
			strike = .40 * envelope(phase, .12, .35, .57, .89)
			crouch = .88 * envelope(phase, .02, .34, .71, .99)
			wing_open = -.38 * crouch
			turn = .24 * sin(TAU * phase) * crouch
		15:
			raise_arm = .65 * envelope(phase, .02, .35, .63, .95)
			crouch = .25 * raise_arm
			wing_open = -.67 * raise_arm
		23:
			crouch = .92 * (1.0 - smoothstep(.06, .74, phase))
			wing_open = .78 * envelope(phase, .18, .55, .72, .98) - .40 * crouch
		25:
			wing_open = .022 * sin(TAU * phase)
			crouch = .014 * (1.0 - cos(TAU * phase))
		26:
			var glance := envelope(phase, .03, .36, .61, .95)
			turn = -.30 * glance
			crouch = .16 * glance
			wing_open = -.16 * glance
		27:
			wing_open = .86 * envelope(phase, .05, .39, .72, .99)
			raise_arm = .47 * wing_open
			turn = .16 * sin(TAU * phase) * wing_open
		28:
			crouch = .56 * envelope(phase, .02, .40, .67, .97)
			raise_arm = .25 * crouch
			wing_open = .49 * crouch
		31:
			raise_arm = .38 * (1.0 - smoothstep(0.0, .32, phase))
			strike = .60 * (1.0 - smoothstep(.20, .98, phase)) + .33 * envelope(phase, 0.0, .19, .24, .53)
			wing_open = .31 * strike
			turn = .38 * raise_arm - .47 * strike
			lead = -1.0
		32:
			strike = .85 * envelope(phase, .05, .33, .67, .98)
			turn = -1.12 * sin(TAU * phase) * strike
			wing_open = .72 * strike
			crouch = .27 * strike
	var feet := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.UP, .36 * turn)
	turn_world(rig, RootJoint, Vector3.RIGHT, .17 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .46 * crouch - .19 * raise_arm)
	turn_world(rig, "bip01 spine2", Vector3.UP, .75 * turn)
	turn_world(rig, "bip01 head", Vector3.UP, -.18 * turn)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.35 * crouch - .18 * raise_arm)
	for side: String in ["l", "r"]:
		var direction := 1.0 if side == "l" else -1.0
		var active := 1.0 if direction == lead or group in [5, 15, 32] else .32
		turn_world(rig, "bip01 %s clavicle" % side, Vector3.BACK, direction * .17 * active * raise_arm)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.BACK,
			direction * (.43 * active * raise_arm + .32 * strike + (.34 if group == 32 else .0) * strike))
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT,
			-active * (1.48 * raise_arm + 1.19 * strike))
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -active * (.69 * raise_arm - .23 * strike))
		turn_world(rig, "bip01 %s hand" % side, Vector3.UP, direction * (.22 * strike - .16 * raise_arm))
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.58 * crouch - .25 * active * raise_arm)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .82 * crouch + .37 * active * raise_arm)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -.24 * crouch)
		turn_world(rig, "gargoyle %s mainwing1" % side, Vector3.UP, -direction * .80 * wing_open)
		turn_world(rig, "gargoyle %s mainwing1" % side, Vector3.BACK, direction * .51 * wing_open)
		turn_world(rig, "gargoyle %s mainwing2" % side, Vector3.RIGHT, -.40 * wing_open)
		turn_world(rig, "gargoyle %s wing3" % side, Vector3.UP, direction * .24 * wing_open)
	anchor_hind_paws(rig, feet)



func pose_rolled_fall(rig: Skeleton3D, phase: float, body: int) -> void:
	var side := -1.0 if body == Destroyer else 1.0
	var fall := smoothstep(.08, .67, phase)
	var settle := smoothstep(.60, .97, phase)
	var recoil := envelope(phase, .0, .22, .43, .65)
	var swing := envelope(phase, .13, .43, .53, .89)
	turn_world(rig, RootJoint, Vector3.RIGHT, -.14 * recoil - 1.42 * fall)
	turn_world(rig, RootJoint, Vector3.FORWARD, side * (.20 * recoil + .35 * fall - .14 * settle))
	turn_world(rig, RootJoint, Vector3.UP, side * .36 * fall)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .28 * swing - .11 * settle)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .41 * recoil + .19 * fall)
	turn_world(rig, "bip01 head", Vector3.UP, -.18 * side * fall)
	for label: String in ["l", "r"]:
		var direction := 1.0 if label == "l" else -1.0
		var nearer := direction * side
		turn_world(rig, "bip01 %s upperarm" % label, Vector3.BACK, direction * (.47 * recoil + .52 * fall))
		turn_world(rig, "bip01 %s forearm" % label, Vector3.RIGHT, -.38 * swing + .12 * settle)
		turn_world(rig, "bip01 %s thigh" % label, Vector3.RIGHT, -.53 * swing - (.20 + .16 * nearer) * fall)
		turn_world(rig, "bip01 %s calf" % label, Vector3.RIGHT, .50 * swing + (.31 - .15 * nearer) * fall)
		turn_world(rig, "bip01 %s foot" % label, Vector3.RIGHT, .19 * settle)
		turn_world(rig, "gargoyle %s mainwing1" % label, Vector3.BACK, direction * (.37 * recoil - .24 * swing + .42 * settle))
		turn_world(rig, "gargoyle %s mainwing1" % label, Vector3.UP, -direction * (.38 * fall + .18 * nearer * swing))
		turn_world(rig, "gargoyle %s mainwing2" % label, Vector3.RIGHT, .37 * swing - .38 * settle)
		turn_world(rig, "gargoyle %s wing3" % label, Vector3.UP, direction * .24 * settle)
	var hip := rig.find_bone(RootJoint)
	var placement := rig.get_bone_global_pose(hip)
	placement.origin += rig.global_basis.inverse() * (Vector3.BACK * (.36 * fall + .08 * settle)
		+ Vector3.RIGHT * (.11 * side * fall))
	rig.set_bone_global_pose(hip, placement)
