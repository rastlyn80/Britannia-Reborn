# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Body := 785
const PeaceWalk := "MolochPeaceWalk"
const WalkJoints := ["bip01 spine2", "bip01 spine3", "bip01 head", "bip01 l upperarm", "bip01 r upperarm",
	"bip01 l upperarm 02", "bip01 l upperarm 03", "bip01 l forearm 02", "bip01 l forearm 03"]
const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/moloch-enhanced/"
const Hip := "bip01 "
const Clips := {1: "MolochCombatRest", 3: "Death2", 4: "MolochLeftHammer", 5: "MolochRightHammer",
	10: "MolochRecoil", 11: "MolochLowSearch", 12: "MolochRaisedStrike", 15: "MolochFourArmGuard",
	23: "MolochCrouchedRise", 25: "MolochQuietRest", 26: "MolochNearWatch",
	27: "MolochWideThreat", 28: "MolochBracedCharge"}
const Times := {1: 1.18, 3: 1.0, 4: .91, 5: .95, 10: .61, 11: 1.0, 12: .93, 15: .60,
	23: 1.18, 25: 1.43, 26: 1.02, 27: 1.08, 28: .68}
const Left := ["bip01 l upperarm", "bip01 l forearm", "bip01 l hand", "bip01 l upperarm 02", "bip01 l forearm 02", "mesh03"]
const Right := ["bip01 r upperarm", "bip01 r forearm", "bip01 r hand", "bip01 l upperarm 03", "bip01 l forearm 03", "mesh12"]
const MolochJoints := [Hip, "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 spine3", "bip01 neck", "bip01 head",
	"bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf", "bip01 l horselink",
	"bip01 r horselink", "bip01 l foot", "bip01 r foot"]


func run() -> void:
	var row := Registry.entry(Body)
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
		var skins: Array[Dictionary] = []
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			skins.append(Ground.skin_points(mesh, rig))
		for group: int in Clips:
			var motion := fit_grounded(player, rig, skins, Times[group], Hip, MolochJoints + Left + Right, pose_moloch.bind(group), .004)
			if group in [1, 25]:
				motion.loop_mode = Animation.LOOP_LINEAR
			assert(library.add_animation(Clips[group], motion) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Destination + "%d-%s.scn" % [Body, treatment], ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		add_peace_walk(Destination + "%d-%s.scn" % [Body, treatment])
		print("MOLOCH ENHANCED ", treatment, " ", Clips.size() + 1, " motions")
	quit()


func pose_moloch(rig: Skeleton3D, phase: float, group: int) -> void:
	if group == 3:
		pose_back_fall(rig, phase)
		return
	var reach := 0.0
	var rise := 0.0
	var crouch := 0.0
	var open := 0.0
	var yaw := 0.0
	var lead := 1.0
	match group:
		1, 25:
			var breath := sin(TAU * phase)
			rise = .034 * breath if group == 1 else .019 * breath
			crouch = (.036 if group == 1 else .013) * (1.0 - cos(TAU * phase))
			open = .024 if group == 1 else -.075
			yaw = .018 * breath
		4, 5, 12:
			lead = -1.0 if group == 5 else 1.0
			rise = envelope(phase, .03, .25, .36, .54)
			reach = envelope(phase, .30, .55, .70, .98)
			crouch = .84 * reach
			open = .34 * rise - .21 * reach
			yaw = lead * (.33 * rise - .51 * reach)
			if group == 12:
				open += .61 * rise
		10:
			rise = .55 * envelope(phase, .0, .20, .37, .90)
			crouch = -.35 * rise
			yaw = -.54 * rise
			open = .24 * rise
		11:
			crouch = .63 * envelope(phase, .05, .30, .75, .99)
			reach = .31 * crouch
			yaw = .48 * sin(TAU * phase) * crouch
		15:
			var guard := envelope(phase, .02, .32, .58, .98)
			rise = .56 * guard
			open = .42 * guard
			crouch = .39 * guard
		23:
			crouch = 1.21 * (1.0 - smoothstep(.08, .57, phase))
			rise = .66 * envelope(phase, .22, .52, .72, .98)
			open = .94 * rise - .24 * crouch
			yaw = .25 * rise
		26:
			var look := envelope(phase, .06, .40, .60, .96)
			yaw = -.66 * look
			crouch = .19 * look
			open = -.14 * look
		27:
			open = .95 * envelope(phase, .04, .40, .65, .98)
			rise = .39 * open
			crouch = -.24 * open
			yaw = .20 * open * sin(TAU * phase)
		28:
			crouch = .62 * envelope(phase, .04, .37, .68, .99)
			rise = .37 * crouch
			reach = .45 * crouch
			open = .34 * crouch
	turn_world(rig, Hip, Vector3.UP, .22 * yaw)
	turn_world(rig, Hip, Vector3.RIGHT, .21 * crouch)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, .48 * crouch - .24 * rise)
	turn_world(rig, "bip01 spine3", Vector3.UP, .82 * yaw)
	turn_world(rig, "bip01 head", Vector3.UP, -.25 * yaw)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.34 * crouch - .18 * rise)
	for arm: Array in [Left, Right]:
		var side := 1.0 if arm == Left else -1.0
		var effort := 1.0 if side == lead or group in [15, 23, 27, 28] else .36
		turn_world(rig, arm[0], Vector3.BACK, side * (1.24 * rise * effort + .63 * open - .39 * reach))
		turn_world(rig, arm[0], Vector3.RIGHT, -effort * (1.13 * reach + .48 * rise))
		turn_world(rig, arm[1], Vector3.RIGHT, -.56 * rise * effort + .28 * reach)
		turn_world(rig, arm[2], Vector3.UP, side * (.29 * reach - .22 * rise))
		var lower := .78 * reach + .34 * rise
		turn_world(rig, arm[3], Vector3.BACK, side * (.40 * open - .38 * lower))
		turn_world(rig, arm[3], Vector3.RIGHT, -.68 * lower * (1.07 if side != lead else .69))
		turn_world(rig, arm[4], Vector3.RIGHT, -.52 * rise + .31 * reach)
		turn_world(rig, arm[5], Vector3.UP, -.23 * side * lower)
		var leg := "l" if side > 0.0 else "r"
		turn_world(rig, "bip01 %s thigh" % leg, Vector3.RIGHT, -.67 * crouch - .31 * effort * rise)
		turn_world(rig, "bip01 %s calf" % leg, Vector3.RIGHT, .79 * crouch + .37 * effort * rise)
		turn_world(rig, "bip01 %s horselink" % leg, Vector3.RIGHT, .35 * crouch)
		turn_world(rig, "bip01 %s foot" % leg, Vector3.RIGHT, -.44 * crouch)


func pose_back_fall(rig: Skeleton3D, phase: float) -> void:
	var fall := smoothstep(.20, .70, phase)
	var settle := smoothstep(.68, .99, phase)
	var flinch := envelope(phase, .02, .22, .42, .68)
	turn_world(rig, Hip, Vector3.RIGHT, -.22 * flinch - 1.47 * fall)
	turn_world(rig, Hip, Vector3.FORWARD, -.27 * flinch + .23 * fall)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.32 * flinch + .12 * settle)
	turn_world(rig, "bip01 spine3", Vector3.UP, .29 * flinch - .18 * fall)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .24 * settle)
	for arm: Array in [Left, Right]:
		var side := 1.0 if arm == Left else -1.0
		turn_world(rig, arm[0], Vector3.BACK, side * (.97 * flinch + .55 * fall))
		turn_world(rig, arm[0], Vector3.RIGHT, .55 * fall)
		turn_world(rig, arm[1], Vector3.RIGHT, -.64 * flinch + .18 * settle)
		turn_world(rig, arm[3], Vector3.BACK, side * (.20 * flinch + .47 * fall))
		turn_world(rig, arm[3], Vector3.RIGHT, -.41 * flinch + .24 * settle)
		turn_world(rig, arm[4], Vector3.RIGHT, -.59 * flinch + .36 * settle)
		var leg := "l" if side > 0.0 else "r"
		turn_world(rig, "bip01 %s thigh" % leg, Vector3.RIGHT, -.65 * flinch - (.40 + .18 * side) * fall)
		turn_world(rig, "bip01 %s calf" % leg, Vector3.RIGHT, .81 * flinch + (.19 - .13 * side) * fall)
		turn_world(rig, "bip01 %s foot" % leg, Vector3.RIGHT, .31 * settle)
	var bone := rig.find_bone(Hip)
	var pose := rig.get_bone_global_pose(bone)
	pose.origin += rig.global_basis.inverse() * (Vector3.FORWARD * (.58 * fall + .12 * settle) + Vector3.RIGHT * .11 * fall)
	rig.set_bone_global_pose(bone, pose)


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
	var sway := sin(TAU * phase)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, -.14)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.086 + .03 * sway)
	for arms: Array in [Left, Right]:
		var side := 1.0 if arms == Left else -1.0
		turn_world(rig, arms[0], Vector3.BACK, -.09 * side)
		turn_world(rig, arms[3], Vector3.BACK, -.095 * side)
		turn_world(rig, arms[3], Vector3.RIGHT, .11 * side * sway)
		turn_world(rig, arms[4], Vector3.RIGHT, -.08 * side * sway)
