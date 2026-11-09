extends "res://../scripts/bake-frost-through-gargoyle-actions.gd"

const LATTICE_CLIPS := {
	123: {15: "LatticeWingBrace", 18: "LatticeWingDisplay"},
	785: {15: "MolochHighGuard", 18: "MolochShoulderCheck"},
	189: {15: "BruteCrouch", 18: "BruteChallenge"},
	241: {15: "OniLowGuard", 18: "OniOverheadGesture"},
	791: {4: "BeetleLowerHead", 11: "BeetleRest"},
	770: {5: "MeerMageHighSweep", 6: "MeerMageSideSweep", 15: "MeerMageGuard", 18: "MeerMageLook"},
	301: {15: "TreefellowBrace", 18: "TreefellowLook"},
	277: {10: "CuSidheScent"},
	773: {5: "MeerCaptainHighCut", 6: "MeerCaptainSideCut", 15: "MeerCaptainBrace", 18: "MeerCaptainLook"},
}
const ETHEREAL_WINGS := ["box02", "box03", "box04", "box05", "box06", "box07"]
const MOLOCH_ARMS := ["bip01 l upperarm 02", "bip01 l forearm 02", "bip01 l upperarm 03", "bip01 l forearm 03"]
const BEETLE_JOINTS := ["bip01 head", "bip01 pelvis", "spine 02", "small pincher r", "small pincher l",
	"bip01 r calf", "bip01 l calf", "bip01 r foot", "bip01 l foot",
	"bip01 r calf b", "bip01 l calf b", "bip01 r foot b", "bip01 l foot b",
	"bip01 r calf c", "bip01 l calf c", "bip01 r foot c", "bip01 l foot c"]

func run() -> void:
	for body: int in LATTICE_CLIPS:
		var row := Registry.entry(body).duplicate(true)
		if row.get("classic_gesture_batch") == "lattice_through_meer_actions" or row.has("beetle_rest_native_sha256"):
			push_error("Use the retained base rather than rebaking an active fitted scene")
			quit(1)
			return
		var assets := {}
		for treatment: String in row.assets:
			var path := Registry.asset_path(row, treatment)
			var digest: String = (row.asset_sha256[treatment] if row.has("asset_sha256")
				else row.saved_scenes[treatment].scene_sha256)
			assert(digest == FileAccess.get_sha256(path))
			assets[treatment] = path
		row.assets = assets
		Registry.entries[body] = row
		fitting_body = body
		bake_body(body, "lattice-through-meer-%d" % body, LATTICE_CLIPS[body],
			["bake-lattice-through-meer-actions.gd",
			 "bake-frost-through-gargoyle-actions.gd", "bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	if fitting_body == 791:
		return fit_grounded(player, rig, skins, 0.56 if slot == 4 else 0.95, "bip 01", BEETLE_JOINTS,
			pose_beetle.bind(slot))
	if fitting_body == 277:
		return fit_grounded(player, rig, skins, 0.64, "bip01",
			["bip01 neck", "bip01 head", "bip01 jaw", "bip01 tail1"], pose_cu_sidhe, 0.014)
	var joints := UPPER + STANCE
	var root_bone := "bip01"
	if fitting_body == 123:
		joints += ETHEREAL_WINGS
	elif fitting_body == 785:
		root_bone = "bip01 "
		joints += MOLOCH_ARMS
	elif fitting_body == 189:
		root_bone = "bip_01"
		joints = joints.map(func(name: String) -> String: return name.replace("bip01", root_bone))
	return fit_grounded(player, rig, skins, 0.53 if slot == 15 else 0.88, root_bone, pose_joints(joints, rig),
		pose_ranked.bind(slot))

func pose_joints(joints: Array, rig: Skeleton3D) -> Array:
	return joints.filter(func(name: String) -> bool: return rig.find_bone(name) >= 0)

func bend(rig: Skeleton3D, joint: String, axis: Vector3, angle: float) -> void:
	var prefix := "bip_01 " if fitting_body == 189 else "bip01 "
	var name := prefix + joint
	assert(rig.find_bone(name) >= 0, name)
	turn_world(rig, name, axis, angle)

func pose_ranked(rig: Skeleton3D, phase: float, slot: int) -> void:
	var effort := smoothstep(0.03, 0.37, phase) * (1.0 - smoothstep(0.54, 0.99, phase))
	var twist := effort * sin(TAU * phase)
	if fitting_body in [770, 773]:
		pose_meer(rig, slot, effort, twist)
		return
	if fitting_body == 123:
		var flare := 0.21 if slot == 15 else 1.04
		var stroke := 0.08 if slot == 15 else 0.53
		turn_world(rig, "box02", Vector3.UP, -flare * effort)
		turn_world(rig, "box05", Vector3.UP, flare * effort)
		turn_world(rig, "box03", Vector3.FORWARD, stroke * effort)
		turn_world(rig, "box06", Vector3.FORWARD, -stroke * effort)
		turn_world(rig, "box04", Vector3.UP, 0.30 * flare * twist)
		turn_world(rig, "box07", Vector3.UP, -0.30 * flare * twist)
		bend(rig, "spine2", Vector3.RIGHT, (-0.14 if slot == 15 else 0.24) * effort)
		bend(rig, "head", Vector3.RIGHT, -0.23 * effort)
		return
	if fitting_body == 785:
		bend(rig, "spine1", Vector3.UP, 0.39 * twist)
		bend(rig, "head", Vector3.UP, 0.35 * twist)
		if slot == 15:
			bend(rig, "l upperarm", Vector3.RIGHT, -0.72 * effort)
			bend(rig, "r upperarm", Vector3.RIGHT, -0.56 * effort)
			bend(rig, "l forearm", Vector3.RIGHT, -0.35 * effort)
			bend(rig, "r forearm", Vector3.RIGHT, -0.26 * effort)
		else:
			bend(rig, "r upperarm", Vector3.UP, 0.39 * effort)
			bend(rig, "l upperarm", Vector3.UP, 0.31 * effort)
		turn_world(rig, MOLOCH_ARMS[0], Vector3.RIGHT, (-0.22 if slot == 15 else 0.31) * effort)
		turn_world(rig, MOLOCH_ARMS[2], Vector3.RIGHT, (-0.22 if slot == 15 else -0.27) * effort)
		return
	if slot == 15:
		bend(rig, "spine1", Vector3.RIGHT, (0.32 if fitting_body == 241 else -0.24) * effort)
		bend(rig, "l thigh", Vector3.RIGHT, -0.29 * effort)
		bend(rig, "r thigh", Vector3.RIGHT, -0.20 * effort)
		bend(rig, "l calf", Vector3.RIGHT, 0.36 * effort)
		bend(rig, "r calf", Vector3.RIGHT, 0.25 * effort)
		bend(rig, "l upperarm", Vector3.RIGHT, -0.56 * effort)
		bend(rig, "r upperarm", Vector3.RIGHT, -0.31 * effort)
		bend(rig, "l forearm", Vector3.RIGHT, -0.31 * effort)
		return
	var raise_arm := 1.03 if fitting_body == 241 else 0.76 if fitting_body == 189 else 0.33
	bend(rig, "r upperarm", Vector3.RIGHT, -raise_arm * effort)
	bend(rig, "r forearm", Vector3.RIGHT, -0.63 * raise_arm * effort)
	bend(rig, "spine2", Vector3.UP, 0.31 * twist)
	bend(rig, "head", Vector3.RIGHT, -0.35 * effort)

func pose_meer(rig: Skeleton3D, slot: int, effort: float, twist: float) -> void:
	if slot in [5, 6]:
		var high := slot == 5
		var strong_side := "r" if high else "l"
		var other_side := "l" if high else "r"
		bend(rig, strong_side + " upperarm", Vector3.RIGHT, (-0.97 if high else -0.45) * effort)
		bend(rig, strong_side + " forearm", Vector3.RIGHT, 0.52 * effort)
		bend(rig, other_side + " upperarm", Vector3.RIGHT, -0.24 * effort)
		bend(rig, "spine2", Vector3.UP, (0.46 if high else -0.54) * effort)
		bend(rig, "l thigh", Vector3.RIGHT, -0.18 * effort)
		bend(rig, "l calf", Vector3.RIGHT, 0.20 * effort)
	elif slot == 15:
		bend(rig, "spine1", Vector3.RIGHT, 0.25 * effort)
		bend(rig, "l upperarm", Vector3.RIGHT, -0.53 * effort)
		bend(rig, "r upperarm", Vector3.RIGHT, -0.37 * effort)
		bend(rig, "l forearm", Vector3.RIGHT, -0.32 * effort)
		bend(rig, "r forearm", Vector3.RIGHT, -0.32 * effort)
	else:
		bend(rig, "head", Vector3.UP, 0.55 * twist)
		bend(rig, "head", Vector3.RIGHT, 0.23 * effort)
		bend(rig, "spine2", Vector3.UP, 0.22 * twist)

func pose_cu_sidhe(rig: Skeleton3D, phase: float) -> void:
	var scent := smoothstep(0.02, 0.34, phase) * (1.0 - smoothstep(0.58, 1.0, phase))
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -0.18 * scent)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -0.29 * scent)
	turn_world(rig, "bip01 jaw", Vector3.RIGHT, 0.11 * scent)
	turn_world(rig, "bip01 tail1", Vector3.UP, 0.15 * scent * sin(TAU * phase))

func pose_beetle(rig: Skeleton3D, phase: float, slot: int) -> void:
	if slot == 11:
		var settle := smoothstep(0.03, 0.68, phase)
		var bob := sin(TAU * phase * 2.0) * smoothstep(0.15, 0.43, phase) * (1.0 - smoothstep(0.50, 0.88, phase))
		turn_world(rig, "bip01 pelvis", Vector3.RIGHT, 0.09 * settle)
		turn_world(rig, "bip01 head", Vector3.RIGHT, 0.26 * settle + 0.08 * bob)
		for side: String in ["l", "r"]:
			var sign := 1.0 if side == "l" else -1.0
			for section: String in ["", " b", " c"]:
				turn_world(rig, "bip01 %s calf%s" % [side, section], Vector3.FORWARD, sign * 0.23 * settle)
				turn_world(rig, "bip01 %s foot%s" % [side, section], Vector3.FORWARD, -sign * 0.31 * settle)
		return
	var effort := smoothstep(0.0, 0.31, phase) * (1.0 - smoothstep(0.40, 0.96, phase))
	turn_world(rig, "bip01 pelvis", Vector3.RIGHT, 0.20 * effort)
	turn_world(rig, "bip01 head", Vector3.RIGHT, 0.28 * effort)
	turn_world(rig, "small pincher r", Vector3.UP, 0.14 * effort)
	turn_world(rig, "small pincher l", Vector3.UP, -0.14 * effort)
	for side: String in ["l", "r"]:
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, 0.16 * effort)
		turn_world(rig, "bip01 %s foot" % side, Vector3.RIGHT, -0.18 * effort)
