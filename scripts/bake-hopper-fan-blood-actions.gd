extends "res://../scripts/bake-zombie-actions.gd"

const RECIPES := {
	302: ["skittering-hopper-distinct", {15:"HopperRecoil", 18:"HopperStretch"}],
	247: ["fan-dancer-distinct", {16:"FanGuardLeft", 17:"FanFlourish"}],
	159: ["blood-elemental-distinct", {7:"BloodOverhead", 8:"BloodHeldReach", 15:"BloodRecoilRight",
		16:"BloodRecoilLeft", 18:"BloodReach"}],
}
const JOINTS := {
	302: ["bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
		"bip01 l upperarm", "bip01 l forearm", "bip01 r upperarm", "bip01 r forearm",
		"bip01 ponytail1", "bip01 ponytail11", "bip01 ponytail2", "bip01 ponytail21"],
	247: ["bip01 spine1", "bip01 head", "bip01 l upperarm", "bip01 l forearm",
		"bip01 l hand", "bip01 r upperarm", "bip01 r forearm", "bip01 r hand"],
	159: ["bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
		"bip01 l upperarm", "bip01 l forearm", "bip01 r upperarm", "bip01 r forearm"],
}

var current_body := 0
var current_slot := 0

func run() -> void:
	for body: int in RECIPES:
		current_body = body
		var recipe: Array = RECIPES[body]
		bake_body(body, recipe[0], recipe[1], ["bake-hopper-fan-blood-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	var library := player.get_animation_library("")
	var original := library.get_animation("Idle")
	var seed := original.duplicate(true) as Animation
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	for name: String in JOINTS[current_body]:
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
	current_slot = slot
	var compatible_slot: int = {7:6, 8:18, 17:18}.get(slot, slot)
	var fitted := super.fit_troll(player, rig, skins, compatible_slot)
	player.stop()
	library.remove_animation("Idle")
	assert(library.add_animation("Idle", original) == OK)
	return fitted

func pose_troll(rig: Skeleton3D, _compatible_slot: int, phase: float) -> void:
	match current_body:
		302: hopper_pose(rig, current_slot, phase)
		247: fan_pose(rig, current_slot, phase)
		159: blood_pose(rig, current_slot, phase)

func hopper_pose(rig: Skeleton3D, slot: int, phase: float) -> void:
	var accent := smoothstep(0.07, 0.42, phase) * (1.0 - smoothstep(0.51, 0.96, phase))
	var trailing := smoothstep(0.18, 0.51, phase) * (1.0 - smoothstep(0.61, 0.98, phase))
	if slot == 15:
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.36 * accent)
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, -0.23 * accent)
		turn_world(rig, "bip01 neck", Vector3.RIGHT, -0.15 * accent)
		for side: String in ["l", "r"]:
			turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, 0.46 * accent)
			turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -0.27 * accent)
		for whisker: String in ["bip01 ponytail1", "bip01 ponytail2"]:
			turn_world(rig, whisker, Vector3.RIGHT, -0.40 * trailing)
		return
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, 0.09 * accent)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, 0.16 * accent)
	turn_world(rig, "bip01 head", Vector3.UP, -0.16 * trailing)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.20 * accent)
	turn_world(rig, "bip01 ponytail11", Vector3.RIGHT, 0.17 * trailing)
	turn_world(rig, "bip01 ponytail21", Vector3.RIGHT, 0.13 * trailing)

func fan_pose(rig: Skeleton3D, slot: int, phase: float) -> void:
	var lift := smoothstep(0.08, 0.38, phase) * (1.0 - smoothstep(0.56, 0.97, phase))
	if slot == 16:
		turn_world(rig, "bip01 spine1", Vector3.UP, 0.30 * lift)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.68 * lift)
		turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -0.75 * lift)
		turn_world(rig, "bip01 l hand", Vector3.UP, 0.31 * lift)
		return
	var cross := smoothstep(0.32, 0.53, phase) * (1.0 - smoothstep(0.69, 0.98, phase))
	turn_world(rig, "bip01 spine1", Vector3.UP, -0.24 * lift + 0.28 * cross)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -0.16 * lift)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.85 * lift)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.74 * lift)
	turn_world(rig, "bip01 r hand", Vector3.UP, 0.67 * cross)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.73 * cross)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -0.85 * cross)
	turn_world(rig, "bip01 l hand", Vector3.UP, -0.50 * cross)

func blood_pose(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.06, 0.42, phase) * (1.0 - smoothstep(0.60, 0.98, phase))
	var hold := smoothstep(0.04, 0.20, phase) * (1.0 - smoothstep(0.77, 0.99, phase))
	var torso := joint_world(rig, "bip01 spine2")
	var right := joint_world(rig, "bip01 r hand")
	var left := joint_world(rig, "bip01 l hand")
	match slot:
		7:
			turn_world(rig, "bip01 spine1", Vector3.UP, -0.28 * pulse)
			turn_world(rig, "bip01 head", Vector3.RIGHT, -0.17 * pulse)
			fit_arm(rig, "l", left.lerp(torso + Vector3(0.26, 0.86, 0.07), pulse))
			fit_arm(rig, "r", right.lerp(torso + Vector3(-0.70, 0.11, 0.24), pulse))
		8:
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.12 * hold)
			fit_arm(rig, "r", right.lerp(torso + Vector3(-0.47, 0.18, 0.59), hold))
			fit_arm(rig, "l", left.lerp(torso + Vector3(0.48, -0.05, 0.53), hold))
		15:
			turn_world(rig, "bip01 spine2", Vector3.UP, 0.22 * pulse)
			fit_arm(rig, "r", right.lerp(torso + Vector3(-0.61, -0.10, 0.42), pulse))
		16:
			turn_world(rig, "bip01 spine2", Vector3.UP, -0.27 * pulse)
			fit_arm(rig, "l", left.lerp(torso + Vector3(0.31, 0.43, 0.32), pulse))
			fit_arm(rig, "r", right.lerp(torso + Vector3(-0.31, 0.29, 0.34), 0.65 * pulse))
		18:
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.15 * pulse)
			fit_arm(rig, "r", right.lerp(torso + Vector3(-0.40, 0.11, 0.65), pulse))
			fit_arm(rig, "l", left.lerp(torso + Vector3(0.43, 0.01, 0.56), pulse))
