extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const NEXT_ACTIONS := {182: {15: "OrcBomberBrace", 18: "OrcBomberScan", 100: "BombFollowThrough"},
	244: {11: "RuneCrestProbe"}, 777: {15: "DopplegangerRecoil", 18: "DopplegangerReach"}}
const BIPED := ["bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm",
	"bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf"]
const CREST := ["bip01 head", "bone01", "bone02"]

func run() -> void:
	for identity: int in NEXT_ACTIONS:
		var row := Registry.entry(identity)
		if row.get("classic_gesture_batch") == "bomber_ogre_rune_dopple_actions":
			push_error("Refusing to overwrite an active creature action package")
			quit(1)
			return
		for treatment: String in row.assets:
			assert(FileAccess.get_sha256(row.assets[treatment]) == row.asset_sha256[treatment])
		fitting_body = identity
		bake_body(identity, "bomber-rune-dopple-%d" % identity, NEXT_ACTIONS[identity],
			["bake-bomber-rune-dopple-actions.gd",
			 "bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	var joints := CREST if fitting_body == 244 else BIPED
	var length := 0.58 if slot == 100 else 0.48 if slot == 15 else 0.80
	return fit_grounded(player, rig, skins, length, "bip01", joints, pose_next.bind(slot))

func pose_next(rig: Skeleton3D, phase: float, slot: int) -> void:
	var impulse := smoothstep(0.07, 0.45, phase) * (1.0 - smoothstep(0.60, 0.98, phase))
	if fitting_body == 244:
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.30 * impulse)
		turn_world(rig, "bip01 head", Vector3.UP, 0.20 * impulse * sin(TAU * phase))
		turn_world(rig, "bone01", Vector3.UP, 0.34 * impulse)
		turn_world(rig, "bone02", Vector3.UP, -0.34 * impulse)
		return
	if fitting_body == 182:
		if slot == 100:
			var release := smoothstep(0.0, 0.18, phase) * (1.0 - smoothstep(0.30, 0.92, phase))
			var dip := smoothstep(0.15, 0.46, phase) * (1.0 - smoothstep(0.58, 1.0, phase))
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.17 * dip)
			turn_world(rig, "bip01 spine2", Vector3.UP, -0.34 * release)
			turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.97 * release + 0.23 * dip)
			turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.31 * release + 0.41 * dip)
			turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, 0.16 * release)
			return
		if slot == 15:
			turn_world(rig, "bip01 spine2", Vector3.UP, -0.27 * impulse)
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.19 * impulse)
			turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.31 * impulse)
			turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -0.32 * impulse)
			turn_world(rig, "bip01 l thigh", Vector3.RIGHT, -0.19 * impulse)
			turn_world(rig, "bip01 r calf", Vector3.RIGHT, 0.22 * impulse)
			return
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.27 * impulse)
		turn_world(rig, "bip01 head", Vector3.UP, 0.58 * impulse * sin(phase * TAU))
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, 0.31 * impulse)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, 0.26 * impulse)
		return
	if slot == 15:
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.47 * impulse)
		turn_world(rig, "bip01 spine2", Vector3.FORWARD, 0.18 * impulse)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.27 * impulse)
		for side: String in ["l", "r"]:
			turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -0.14 * impulse)
			turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, 0.26 * impulse)
		return
	var windup := smoothstep(0.04, 0.26, phase) * (1.0 - smoothstep(0.31, 0.47, phase))
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.34 * impulse)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -0.18 * impulse)
	for side: String in ["l", "r"]:
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -0.82 * impulse - 0.26 * windup)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, 0.21 * impulse - 0.81 * windup)
