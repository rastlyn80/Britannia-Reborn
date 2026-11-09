extends "res://../scripts/bake-zombie-actions.gd"

const ACTIONS := {
	259: {17: "GrizzleBreath"},
	264: {17: "ChangelingWingRoll"},
	72: {3: "Death2", 5: "ForelegThrust", 6: "PincerOverhead", 13: "MatriarchBurst",
		15: "PincerBrace", 16: "PincerRecoil", 18: "MandibleTwitch"},
}
const GRIZZLE_JOINTS := ["bip01 spine2", "bip01 neck", "bip01 head", "bip01 r forearm", "bip01 l forearm"]
const CHANGELING_JOINTS := ["bip01 spine1", "bip01 spine2", "bip01 head", "bone_wingleft", "bone_wingright",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l thigh", "bip01 r thigh"]
var fitting_body := 0
var fitting_burst := false

const LEGS := ["bone_r", "bone_r01", "bone_r02", "bone_r03", "bone_r04", "bone_r05"]
const JOINTS := ["bip01", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 r upperarm", "bip01 r forearm", "bip01 l upperarm", "bip01 l forearm",
	"bip01 tail1", "bone_fangs_l", "bone_fangs_r"] + LEGS

var classic_group := 0

func run() -> void:
	for body: int in ACTIONS:
		var row := Registry.entry(body)
		if row.get("classic_gesture_batch") == "ranked_classic_actions":
			push_error("Refusing to overwrite an active creature action package")
			quit(1)
			return
		for treatment: String in row.assets:
			assert(FileAccess.get_sha256(row.assets[treatment]) == row.asset_sha256[treatment])
	for body: int in ACTIONS:
		fitting_body = body
		bake_body(body, "ranked-%d" % body, ACTIONS[body], ["bake-ranked-classic-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	if fitting_body != 72:
		return fit_fidget(player, rig)
	fitting_burst = slot == 13
	return fit_matriarch(player, rig, skins, 6 if fitting_burst else slot)

func fit_matriarch(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	classic_group = slot
	var library := player.get_animation_library("")
	var original := library.get_animation("Idle")
	var seed := original.duplicate(true) as Animation
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	for name: String in JOINTS:
		var joint := rig.find_bone(name)
		assert(joint >= 0, name)
		var path := NodePath("%s:%s" % [rig_path, name])
		if seed.find_track(path, Animation.TYPE_ROTATION_3D) < 0:
			var track := seed.add_track(Animation.TYPE_ROTATION_3D)
			seed.track_set_path(track, path)
			seed.rotation_track_insert_key(track, 0.0, rig.get_bone_rest(joint).basis.get_rotation_quaternion())
	player.stop()
	library.remove_animation("Idle")
	assert(library.add_animation("Idle", seed) == OK)
	var base_slot := 2 if slot == 3 else (4 if slot == 5 else slot)
	var motion := super.fit_troll(player, rig, skins, base_slot)
	player.stop()
	library.remove_animation("Idle")
	assert(library.add_animation("Idle", original) == OK)
	return motion

func pose_troll(rig: Skeleton3D, _slot: int, phase: float) -> void:
	if not fitting_burst:
		pose_matriarch(rig, phase)
		return
	var open := smoothstep(0.06, 0.39, phase) * (1.0 - smoothstep(0.62, 0.96, phase))
	var recoil := smoothstep(0.43, 0.63, phase) * (1.0 - smoothstep(0.70, 1.0, phase))
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.22 * open + 0.21 * recoil)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -1.17 * open + 0.43 * recoil)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.FORWARD, sign * 0.34 * open)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -0.40 * open - 0.21 * recoil)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -0.14 * open)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, 0.11 * recoil)

func pose_matriarch(rig: Skeleton3D, phase: float) -> void:
	var impulse := smoothstep(0.04, 0.43, phase) * (1.0 - smoothstep(0.58, 1.0, phase))
	if classic_group == 3:
		var fall := smoothstep(0.08, 0.94, phase)
		var flail := smoothstep(0.11, 0.44, phase) * (1.0 - smoothstep(0.53, 0.90, phase))
		turn_world(rig, "bip01", Vector3.RIGHT, -1.60 * fall)
		turn_world(rig, "bip01", Vector3.FORWARD, 0.43 * fall)
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, 0.15 * fall)
		turn_world(rig, "bip01 tail1", Vector3.RIGHT, -0.34 * fall)
		for i in LEGS.size():
			turn_world(rig, LEGS[i], Vector3.RIGHT, (0.53 + i % 3 * 0.15) * fall)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -1.08 * flail)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.72 * flail)
		return
	if classic_group == 5:
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.16 * impulse)
		turn_world(rig, "bone_r02", Vector3.RIGHT, -0.99 * impulse)
		turn_world(rig, "bone_r03", Vector3.RIGHT, -0.82 * impulse)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.37 * impulse)
		return
	if classic_group == 6:
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.39 * impulse)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -1.37 * impulse)
		turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.37 * impulse)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.53 * impulse)
		return
	if classic_group == 18:
		turn_world(rig, "bip01 head", Vector3.UP, 0.11 * impulse)
		turn_world(rig, "bone_fangs_l", Vector3.UP, -0.16 * impulse)
		turn_world(rig, "bone_fangs_r", Vector3.UP, 0.16 * impulse)
		return
	var right := classic_group == 15
	var side := "r" if right else "l"
	turn_world(rig, "bip01 spine2", Vector3.UP, (0.23 if right else -0.32) * impulse)
	turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -0.45 * impulse)
	turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -0.35 * impulse)

func fit_fidget(player: AnimationPlayer, rig: Skeleton3D) -> Animation:
	var seed := player.get_animation("Idle")
	var motion := seed.duplicate(true) as Animation
	motion.length = 0.80
	motion.loop_mode = Animation.LOOP_NONE
	for track in motion.get_track_count():
		var value: Variant = seed.track_get_key_value(track, 0)
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
		motion.track_insert_key(track, 0.0, value)
	var joints: Array = GRIZZLE_JOINTS if fitting_body == 259 else CHANGELING_JOINTS
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var tracks := {}
	for label: String in joints:
		var bone := rig.find_bone(label)
		assert(bone >= 0, label)
		var path := NodePath("%s:%s" % [rig_path, label])
		var track := motion.find_track(path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(track, path)
		tracks[bone] = track
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 97:
		var phase := frame / 96.0
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		var pulse := smoothstep(0.0, 0.36, phase) * (1.0 - smoothstep(0.58, 1.0, phase))
		if fitting_body == 259:
			turn_world(rig, "bip01 spine2", Vector3.RIGHT, -0.045 * pulse)
			turn_world(rig, "bip01 neck", Vector3.RIGHT, 0.052 * pulse)
			turn_world(rig, "bip01 head", Vector3.UP, 0.045 * sin(TAU * phase))
			turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.025 * pulse)
			turn_world(rig, "bip01 l forearm", Vector3.RIGHT, 0.022 * pulse)
		else:
			var sweep := sin(TAU * phase) * pulse
			turn_world(rig, "bip01 spine1", Vector3.FORWARD, -0.63 * pulse)
			turn_world(rig, "bip01 spine2", Vector3.UP, 0.42 * sweep)
			turn_world(rig, "bip01 head", Vector3.RIGHT, 0.26 * pulse)
			turn_world(rig, "bone_wingleft", Vector3.FORWARD, 0.76 * sweep + 0.43 * pulse)
			turn_world(rig, "bone_wingright", Vector3.FORWARD, -0.87 * sweep - 0.61 * pulse)
			turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.55 * pulse)
			turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.37 * pulse)
			turn_world(rig, "bip01 l thigh", Vector3.RIGHT, 0.29 * pulse)
			turn_world(rig, "bip01 r thigh", Vector3.RIGHT, 0.36 * pulse)
		for bone: int in tracks:
			motion.rotation_track_insert_key(tracks[bone], phase * motion.length, rig.get_bone_pose_rotation(bone))
	return motion
