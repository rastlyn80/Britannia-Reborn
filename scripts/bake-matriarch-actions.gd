extends "res://../scripts/bake-zombie-actions.gd"

const MATRIARCH := {3: "Death2", 6: "MatriarchTailStrike", 15: "MatriarchOverheadBrace",
	16: "MatriarchRecoil", 18: "MatriarchTailLift"}
const JOINTS := ["bip01", "bip01 spine1", "bip01 spine2", "bip01 spine3", "bip01 head",
	"bip01 r upperarm", "bip01 r forearm", "bip01 l upperarm", "bip01 l forearm",
	"bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3", "bip01 tail4"]

var group := 0

func run() -> void:
	assert(Registry.entry(87).classic_action_categories["11"] == "OphidianQueenDip")
	bake_body(87, "matriarch", MATRIARCH, ["bake-matriarch-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	group = slot
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
	var fitted := super.fit_troll(player, rig, skins, 2 if slot == 3 else slot)
	player.stop()
	library.remove_animation("Idle")
	assert(library.add_animation("Idle", original) == OK)
	return fitted

func pose_troll(rig: Skeleton3D, _slot: int, phase: float) -> void:
	var impulse := smoothstep(0.06, 0.40, phase) * (1.0 - smoothstep(0.53, 0.99, phase))
	if group == 3:
		var settle := smoothstep(0.09, 0.94, phase)
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.75 * settle)
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, 0.50 * settle)
		turn_world(rig, "bip01 spine3", Vector3.FORWARD, 0.37 * settle)
		turn_world(rig, "bip01 head", Vector3.RIGHT, 0.21 * settle)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.85 * settle)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -1.10 * settle)
		turn_world(rig, "bip01 tail1", Vector3.UP, -0.36 * settle)
		turn_world(rig, "bip01 tail3", Vector3.UP, 0.31 * settle)
		return
	if group == 6:
		turn_world(rig, "bip01 spine1", Vector3.UP, 0.58 * impulse)
		turn_world(rig, "bip01 tail1", Vector3.UP, -0.85 * impulse)
		turn_world(rig, "bip01 tail2", Vector3.UP, -0.92 * impulse)
		turn_world(rig, "bip01 tail3", Vector3.RIGHT, -0.59 * impulse)
		turn_world(rig, "bip01 tail4", Vector3.RIGHT, -0.35 * impulse)
		return
	if group == 18:
		turn_world(rig, "bip01 head", Vector3.UP, 0.12 * impulse)
		turn_world(rig, "bip01 tail2", Vector3.RIGHT, -0.28 * impulse)
		turn_world(rig, "bip01 tail3", Vector3.RIGHT, -0.53 * impulse)
		turn_world(rig, "bip01 tail4", Vector3.RIGHT, -0.37 * impulse)
		return
	var overhead := group == 15
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, (0.22 if overhead else -0.36) * impulse)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, (-1.21 if overhead else -0.38) * impulse)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.56 * impulse)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, (-0.42 if overhead else -0.66) * impulse)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -0.45 * impulse)
