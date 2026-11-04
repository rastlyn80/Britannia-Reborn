extends "res://../scripts/bake-zombie-actions.gd"

const ROUTES := {
	124: ["evil-mage", {6: "RaisedCast", 15: "WardRecoil", 18: "StafflessBend"}],
	240: ["kappa", {15: "ShellRecoilLeft", 16: "ShellRecoilRight", 18: "JawAlert"}],
	250: ["tsuki-wolf", {15: "PackGuardLeft", 16: "PackGuardRight", 18: "ThreeHeadAlert"}],
}
var current_body: int

func run() -> void:
	for body: int in ROUTES:
		current_body = body
		var source := Registry.entry(body)
		var row := source.duplicate(true)
		row.assets = {}
		for treatment: String in ["original", "rounded", "modern"]:
			row.assets[treatment] = Registry.asset_path(source, treatment)
		Registry.entries[body] = row
		bake_body(body, ROUTES[body][0] + "-distinct", ROUTES[body][1], ["bake-occurrence-gestures.gd", "bake-zombie-actions.gd"])
	quit()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.03, 0.32, phase) * (1.0 - smoothstep(0.48, 1.0, phase))
	var rebound := smoothstep(0.32, 0.62, phase) * (1.0 - smoothstep(0.68, 1.0, phase))
	match current_body:
		124:
			pose_mage(rig, slot, pulse, rebound)
		240:
			pose_kappa(rig, slot, pulse, rebound)
		250:
			pose_wolf(rig, slot, pulse, rebound)

func pose_mage(rig: Skeleton3D, slot: int, pulse: float, rebound: float) -> void:
	if slot == 18:
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.39 * pulse)
		turn_world(rig, "bip01 spine2", Vector3.UP, -0.30 * rebound)
		turn_world(rig, "bip01 head", Vector3.RIGHT, 0.27 * pulse)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.34 * pulse)
		return
	var attack := slot == 6
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, (-0.29 if attack else -0.17) * pulse)
	turn_world(rig, "bip01 spine2", Vector3.UP, (-0.33 if attack else 0.27) * pulse)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -0.24 * pulse + 0.12 * rebound)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, (-1.79 if attack else -1.21) * pulse)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.60 * pulse)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.36 * pulse)

func pose_kappa(rig: Skeleton3D, slot: int, pulse: float, rebound: float) -> void:
	if slot == 18:
		turn_world(rig, "bip01 neck", Vector3.RIGHT, -0.20 * pulse)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.21 * pulse + 0.10 * rebound)
		turn_world(rig, "bone01", Vector3.RIGHT, 0.12 * rebound)
		return
	var side := "l" if slot == 15 else "r"
	var sign := -1.0 if side == "l" else 1.0
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.42 * pulse + 0.56 * rebound)
	turn_world(rig, "bip01 spine2", Vector3.UP, sign * 0.30 * pulse)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -0.28 * pulse + 0.28 * rebound)
	turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -0.74 * pulse + 0.25 * rebound)
	turn_world(rig, "bip01 " + side + " forearm", Vector3.FORWARD, sign * 0.47 * pulse)

func pose_wolf(rig: Skeleton3D, slot: int, pulse: float, rebound: float) -> void:
	if slot == 18:
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.29 * pulse)
		turn_world(rig, "bip01 neck", Vector3.RIGHT, -0.24 * pulse)
		turn_world(rig, "jaw_bone", Vector3.RIGHT, 0.31 * pulse)
		turn_world(rig, "r_neck_bone", Vector3.RIGHT, -0.37 * pulse)
		turn_world(rig, "l_neck_bone", Vector3.RIGHT, -0.26 * maxf(pulse, rebound))
		turn_world(rig, "r_jaw_bone", Vector3.RIGHT, 0.18 * pulse)
		turn_world(rig, "l_jaw_bone", Vector3.RIGHT, 0.20 * rebound)
		return
	var side := "l" if slot == 15 else "r"
	var sign := -1.0 if side == "l" else 1.0
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.19 * pulse - 0.21 * rebound)
	turn_world(rig, "bip01 spine1", Vector3.UP, sign * 0.15 * pulse)
	turn_world(rig, "bip01 head", Vector3.RIGHT, 0.14 * pulse - 0.21 * rebound)
	turn_world(rig, side + "_neck_bone", Vector3.UP, sign * 0.20 * pulse)
	turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -0.41 * rebound)
	turn_world(rig, "bip01 " + side + " forearm", Vector3.FORWARD, sign * 0.36 * pulse)

