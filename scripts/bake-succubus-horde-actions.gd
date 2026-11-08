extends "res://../scripts/bake-zombie-actions.gd"

const SUCCUBUS := {15:"SuccubusWingRecoil", 18:"SuccubusWingLift"}
const HORDE := {3:"Death2", 15:"HordeBrace", 18:"HordeGlance"}
const WING_JOINTS := ["bip01", "bip01 spine1", "bip01 spine2", "bip01 head",
	"box01", "box03", "box04", "box05", "box06", "box07",
	"bip01 r upperarm", "bip01 l upperarm", "bip01 r thigh", "bip01 l thigh",
	"bip01 r calf", "bip01 l calf"]

var fitting_body := 0
var group := 0

func run() -> void:
	fitting_body = 149
	bake_body(149, "succubus", SUCCUBUS, ["bake-succubus-horde-actions.gd", "bake-zombie-actions.gd"])
	fitting_body = 776
	bake_body(776, "horde-minion", HORDE, ["bake-succubus-horde-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	group = slot
	if fitting_body == 776:
		return super.fit_troll(player, rig, skins, 2 if slot == 3 else slot)
	var library := player.get_animation_library("")
	var original := library.get_animation("Idle")
	var seed := original.duplicate(true) as Animation
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	for name: String in WING_JOINTS:
		var joint := rig.find_bone(name)
		assert(joint >= 0)
		var path := NodePath("%s:%s" % [rig_path, name])
		if seed.find_track(path, Animation.TYPE_ROTATION_3D) < 0:
			var track := seed.add_track(Animation.TYPE_ROTATION_3D)
			seed.track_set_path(track, path)
			seed.rotation_track_insert_key(track, 0.0, rig.get_bone_rest(joint).basis.get_rotation_quaternion())
	player.stop()
	library.remove_animation("Idle")
	assert(library.add_animation("Idle", seed) == OK)
	var fitted := super.fit_troll(player, rig, skins, slot)
	player.stop()
	library.remove_animation("Idle")
	assert(library.add_animation("Idle", original) == OK)
	return fitted

func pose_troll(rig: Skeleton3D, _slot: int, phase: float) -> void:
	var impulse := smoothstep(0.06, 0.42, phase) * (1.0 - smoothstep(0.61, 0.99, phase))
	if fitting_body == 149:
		var recoil := group == 15
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, (-0.28 if recoil else 0.19) * impulse)
		turn_world(rig, "bip01 head", Vector3.UP, (0.08 if recoil else -0.28) * impulse)
		for name: String in ["box01", "box07"]:
			turn_world(rig, name, Vector3.RIGHT, (-0.32 if recoil else -0.58) * impulse)
		turn_world(rig, "box03", Vector3.UP, (0.48 if recoil else -0.34) * impulse)
		turn_world(rig, "box05", Vector3.UP, (-0.48 if recoil else 0.34) * impulse)
		turn_world(rig, "box04", Vector3.RIGHT, -0.21 * impulse)
		turn_world(rig, "box06", Vector3.RIGHT, -0.21 * impulse)
		for side: String in ["l", "r"]:
			turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, (-0.50 if recoil else -0.86) * impulse)
			turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -0.11 * impulse)
			turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, 0.22 * impulse)
		return
	if group == 3:
		var fall := smoothstep(0.08, 0.90, phase)
		turn_world(rig, "bip01", Vector3.RIGHT, -1.37 * fall)
		turn_world(rig, "bip01", Vector3.FORWARD, 0.24 * fall)
		turn_world(rig, "bip01 head", Vector3.RIGHT, 0.22 * fall)
		for side: String in ["l", "r"]:
			turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, 0.23 * fall)
			turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, -0.29 * fall)
			turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -0.35 * impulse)
		return
	if group == 15:
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.32 * impulse)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.18 * impulse)
		turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -0.47 * impulse)
		turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.39 * impulse)
		return
	var look := sin(TAU * phase) * impulse
	turn_world(rig, "bip01 spine2", Vector3.UP, 0.28 * look)
	turn_world(rig, "bip01 head", Vector3.UP, 0.76 * look)
	turn_world(rig, "bone_jaw", Vector3.RIGHT, -0.21 * impulse)
