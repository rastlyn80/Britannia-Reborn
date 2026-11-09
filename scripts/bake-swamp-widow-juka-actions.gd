extends "res://../scripts/bake-zombie-actions.gd"

const SWAMP_ACTIONS := {4: "RaiseHead", 9: "ForwardNeckCheck", 10: "TailBalance", 11: "QuietChuff"}
const SWAMP_LENGTHS := {4: 0.48, 9: 0.80, 10: 0.48, 11: 0.96}
const SWAMP_JOINTS := ["bip01 neck", "bip01 neck1", "bip01 neck2", "bip01 neck3",
	"bip01 neck4", "bip01 head", "bone_jaw1", "bip01 tail", "bip01 tail1", "bip01 tail2"]

const WIDOW_ACTIONS := {15: "LowBrace", 18: "AbdomenSignal"}
const WIDOW_LENGTHS := {15: 0.48, 18: 0.80}
const WIDOW_COXA := ["bone04", "bone08", "bone12", "bone16", "bone20", "bone24", "bone28", "bone32"]
const WIDOW_KNEES := ["bone05", "bone09", "bone13", "bone17", "bone21", "bone25", "bone29", "bone33"]

const JUKA_ACTIONS := {6: "AdvancingPalm", 15: "HighRecoil", 16: "LowRecoil", 18: "JukaGlance"}
const JUKA_LENGTHS := {6: 0.64, 15: 0.48, 16: 0.48, 18: 0.8}
const JUKA_JOINTS := ["bip01 spine1", "bip01 spine2", "bip01 head",
	"bip01 l clavicle", "bip01 r clavicle", "bip01 l upperarm", "bip01 r upperarm",
	"bip01 l forearm", "bip01 r forearm", "bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf"]

const ACTIONS := {794: SWAMP_ACTIONS, 799: SWAMP_ACTIONS, 157: WIDOW_ACTIONS, 765: JUKA_ACTIONS}
var fitting_body := 0

func run() -> void:
	for body: int in ACTIONS:
		var row := Registry.entry(body).duplicate(true)
		if row.get("classic_gesture_batch") == "swamp_widow_juka_actions":
			push_error("Refusing to overwrite an active creature action package")
			quit(1)
			return
		var assets := {}
		for treatment: String in row.asset_sha256:
			var path := Registry.asset_path(row, treatment)
			assert(FileAccess.get_sha256(path) == row.asset_sha256[treatment])
			assets[treatment] = path
		assert(assets.size() == 3)
		row.assets = assets
		Registry.entries[body] = row
	for body: int in ACTIONS:
		fitting_body = body
		bake_body(body, "swamp-widow-juka-%d" % body, ACTIONS[body],
			["bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	if fitting_body == 157:
		var joints := ["bone01", "bone02"] + WIDOW_COXA + WIDOW_KNEES
		return fit_grounded(player, rig, skins, WIDOW_LENGTHS[slot], "bone01", joints, pose_widow.bind(slot))
	if fitting_body == 765:
		return fit_grounded(player, rig, skins, JUKA_LENGTHS[slot], "bip01", JUKA_JOINTS, pose_juka.bind(slot), 0.008)
	return fit_grounded(player, rig, skins, SWAMP_LENGTHS[slot], "bip01", SWAMP_JOINTS, pose_swamp.bind(slot))

func fit_grounded(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], length: float,
		root_name: String, joints: Array, pose: Callable, clearance: float = 0.004) -> Animation:
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	clip.length = length
	clip.loop_mode = Animation.LOOP_NONE
	for track in clip.get_track_count():
		for key in range(clip.track_get_key_count(track) - 1, 0, -1):
			clip.track_remove_key(track, key)
	var joint_tracks := {}
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	for name: String in joints:
		var joint := rig.find_bone(name)
		assert(joint >= 0, name)
		var path := NodePath("%s:%s" % [rig_path, name])
		var track := clip.find_track(path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(track, path)
		joint_tracks[joint] = track
	var root_joint := rig.find_bone(root_name)
	assert(root_joint >= 0)
	var root_path := NodePath("%s:%s" % [rig_path, root_name])
	var placement := clip.find_track(root_path, Animation.TYPE_POSITION_3D)
	if placement < 0:
		placement = clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(placement, root_path)
	player.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 81:
		var phase := float(frame) / 80.0
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		pose.call(rig, phase)
		var gap := INF
		for skin: Dictionary in skins:
			gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		assert(is_finite(gap))
		var hip := rig.get_bone_global_pose(root_joint)
		hip.origin += rig.global_basis.inverse() * Vector3.UP * (clearance - gap)
		rig.set_bone_global_pose(root_joint, hip)
		var time := phase * clip.length
		clip.position_track_insert_key(placement, time, rig.get_bone_pose_position(root_joint))
		for joint: int in joint_tracks:
			clip.rotation_track_insert_key(joint_tracks[joint], time, rig.get_bone_pose_rotation(joint))
	return clip

func pose_swamp(rig: Skeleton3D, phase: float, slot: int) -> void:
	if slot == 4:
		var crouch := smoothstep(0.0, 0.13, phase) * (1.0 - smoothstep(0.20, 0.52, phase))
		var lift := smoothstep(0.22, 0.57, phase) * (1.0 - smoothstep(0.74, 1.0, phase))
		turn_world(rig, "bip01 neck", Vector3.RIGHT, 0.36 * crouch - 0.12 * lift)
		turn_world(rig, "bip01 neck2", Vector3.RIGHT, 0.23 * crouch - 0.12 * lift)
		turn_world(rig, "bip01 head", Vector3.RIGHT, 0.24 * crouch - 0.18 * lift)
		turn_world(rig, "bip01 tail1", Vector3.RIGHT, 0.16 * crouch)
		return
	var reach := smoothstep(0.10, 0.45, phase) * (1.0 - smoothstep(0.58, 0.97, phase))
	if slot == 11:
		var breath := smoothstep(0.18, 0.51, phase) * (1.0 - smoothstep(0.64, 0.95, phase))
		turn_world(rig, "bone_jaw1", Vector3.RIGHT, 0.32 * breath)
		turn_world(rig, "bip01 neck4", Vector3.RIGHT, 0.07 * breath)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.12 * breath)
		return
	if slot == 9:
		var glance := sin(phase * TAU) * reach
		turn_world(rig, "bip01 neck1", Vector3.RIGHT, 0.11 * reach)
		turn_world(rig, "bip01 neck3", Vector3.RIGHT, -0.13 * reach)
		turn_world(rig, "bip01 neck4", Vector3.UP, 0.15 * glance)
		turn_world(rig, "bip01 head", Vector3.UP, 0.24 * glance)
		turn_world(rig, "bone_jaw1", Vector3.RIGHT, 0.13 * reach)
		return
	turn_world(rig, "bip01 neck2", Vector3.RIGHT, 0.16 * reach)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -0.24 * reach)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -0.16 * reach)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, -0.24 * reach)
	turn_world(rig, "bip01 tail2", Vector3.UP, 0.38 * reach)

func pose_widow(rig: Skeleton3D, phase: float, slot: int) -> void:
	var effort := smoothstep(0.05, 0.42, phase) * (1.0 - smoothstep(0.53, 0.98, phase))
	if slot == 15:
		for i in WIDOW_COXA.size():
			var side := -1.0 if i < 4 else 1.0
			var front := i in [2, 3, 4, 5]
			turn_world(rig, WIDOW_COXA[i], Vector3.FORWARD, -side * (0.35 if front else 0.22) * effort)
			turn_world(rig, WIDOW_KNEES[i], Vector3.FORWARD, side * 0.19 * effort)
		turn_world(rig, "bone02", Vector3.RIGHT, -0.16 * effort)
		return
	var swaying := sin(phase * TAU) * effort
	turn_world(rig, "bone02", Vector3.RIGHT, 0.38 * effort)
	turn_world(rig, "bone02", Vector3.UP, 0.19 * swaying)
	for i in WIDOW_COXA.size():
		var side := -1.0 if i < 4 else 1.0
		var outer := i in [0, 3, 4, 7]
		turn_world(rig, WIDOW_COXA[i], Vector3.UP, side * (0.24 if outer else -0.08) * effort)
		turn_world(rig, WIDOW_KNEES[i], Vector3.FORWARD, side * 0.15 * swaying)

func pose_juka(rig: Skeleton3D, phase: float, slot: int) -> void:
	var impulse := smoothstep(0.06, 0.43, phase) * (1.0 - smoothstep(0.57, 0.98, phase))
	if slot == 18:
		var glance := impulse * sin(phase * TAU)
		turn_world(rig, "bip01 head", Vector3.UP, 0.47 * glance)
		turn_world(rig, "bip01 head", Vector3.RIGHT, 0.24 * impulse)
		turn_world(rig, "bip01 spine2", Vector3.UP, 0.19 * impulse)
		turn_world(rig, "bip01 r clavicle", Vector3.FORWARD, 0.11 * impulse)
		return
	if slot == 6:
		var wind := smoothstep(0.04, 0.26, phase) * (1.0 - smoothstep(0.30, 0.44, phase))
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.25 * impulse - 0.12 * wind)
		turn_world(rig, "bip01 spine2", Vector3.UP, 0.34 * impulse - 0.23 * wind)
		turn_world(rig, "bip01 l thigh", Vector3.RIGHT, -0.26 * impulse)
		turn_world(rig, "bip01 l calf", Vector3.RIGHT, 0.30 * impulse)
		turn_world(rig, "bip01 r thigh", Vector3.RIGHT, 0.20 * impulse)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.74 * impulse)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.18 * impulse + 0.27 * wind)
		turn_world(rig, "bip01 l forearm", Vector3.RIGHT, 0.40 * impulse - 0.58 * wind)
		return
	var high := slot == 15
	var direction := 1.0 if high else -1.0
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, (-0.36 if high else 0.31) * impulse)
	turn_world(rig, "bip01 spine2", Vector3.UP, direction * 0.26 * impulse)
	turn_world(rig, "bip01 head", Vector3.RIGHT, direction * 0.18 * impulse)
	turn_world(rig, "bip01 l upperarm", Vector3.FORWARD, -0.28 * impulse)
	turn_world(rig, "bip01 r upperarm", Vector3.FORWARD, 0.32 * impulse)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, (-0.36 if high else 0.20) * impulse)
	turn_world(rig, "bip01 r thigh", Vector3.RIGHT, (-0.21 if high else -0.32) * impulse)
	turn_world(rig, "bip01 r calf", Vector3.RIGHT, 0.28 * impulse)
