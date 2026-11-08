extends "res://../scripts/bake-zombie-actions.gd"

const TERATHAN_ACTIONS := {3:"Death2", 5:"ForelegThrust", 6:"PincerOverhead",
	15:"PincerBrace", 16:"PincerRecoil", 18:"MandibleTwitch"}
const LEGS := ["bone_r", "bone_r01", "bone_r02", "bone_r03", "bone_r04", "bone_r05"]
const JOINTS := ["bip01", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 r upperarm", "bip01 r forearm", "bip01 l upperarm", "bip01 l forearm",
	"bip01 tail1", "bone_fangs_l", "bone_fang_r"] + LEGS

var classic_group := 0

func run() -> void:
	for body: int in [70, 71]:
		assert(Registry.entry(body).classic_action_categories["11"] == "PincerDip")
		bake_body(body, "terathan-%d-distinct" % body, TERATHAN_ACTIONS, ["bake-terathan-distinct-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
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
		turn_world(rig, "bone_fang_r", Vector3.UP, 0.16 * impulse)
		return
	var right := classic_group == 15
	var side := "r" if right else "l"
	turn_world(rig, "bip01 spine2", Vector3.UP, (0.23 if right else -0.32) * impulse)
	turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -0.45 * impulse)
	turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -0.35 * impulse)
