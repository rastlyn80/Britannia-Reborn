extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const NEXT := {
	303: {15: "DevourerBrace", 18: "DevourerBellow"},
	251: {11: "LionScent"},
	787: {15: "AntLionCrouch"},
	300: {15: "CrystalHunch", 18: "CrystalRattle"},
	263: {18: "MinotaurCheck"},
	253: {11: "YomotsuStaffSweep"},
	305: {15: "GoreFiendCurl", 18: "GoreFiendHeadRaise"},
}
const JOINTS := {
	303: ["bip01 spine1", "bip01 neck", "bip01 head", "boner01", "bonel01", "bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm"],
	251: ["bip01 spine1", "bip01 neck", "bip01 head", "jawbone"],
	787: ["spine 01", "spine 03", "head", "antenna l 01", "antenna r 01", "large pincher l 01", "large pincher r 01"],
	300: ["bip01 spine1", "bip01 spine3", "bip01 neck1", "bip01 head", "bip01 l upperarm", "bip01 r upperarm"],
	263: ["bip01 spine1", "bip01 head", "bip01 l upperarm", "bip01 r upperarm", "bip01 tail1"],
	253: ["bip01 spine1", "bip01 head", "bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm"],
	305: ["bip01 spine1", "bip01 spine3", "bip01 neck1", "bip01 neck3", "bip01 head", "bip01 bone jaw2"],
}

func _initialize() -> void:
	create_timer(65.0).timeout.connect(func(): quit(2))
	super._initialize()

func run() -> void:
	for body: int in NEXT:
		var row := Registry.entry(body).duplicate(true)
		if row.get("classic_gesture_batch") == "post_solen_actions":
			push_error("Refusing to overwrite an active creature action package")
			quit(1)
			return
		for treatment: String in row.assets:
			var path := Registry.asset_path(row, treatment)
			var digest: String = (row.saved_scenes[treatment].scene_sha256 if body == 787
				else row.asset_sha256[treatment])
			assert(FileAccess.get_sha256(path) == digest)
		Registry.entries[body] = row
		fitting_body = body
		bake_body(body, "post-solen-%d" % body, NEXT[body],
			["bake-post-solen-actions.gd",
			 "bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	var root_name := "bip 01" if fitting_body == 787 else "bip01"
	return fit_grounded(player, rig, skins, 0.49 if slot == 15 else 0.82, root_name,
		JOINTS[fitting_body], fit_preview.bind(slot))

func fit_preview(rig: Skeleton3D, phase: float, slot: int) -> void:
	var pulse := smoothstep(0.08, 0.42, phase) * (1.0 - smoothstep(0.58, 0.98, phase))
	var sway := pulse * sin(TAU * phase)
	match fitting_body:
		303:
			var brace := slot == 15
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, pulse * (-0.43 if brace else -0.12))
			turn_world(rig, "bip01 neck", Vector3.RIGHT, pulse * (-0.17 if brace else 0.22))
			turn_world(rig, "bip01 head", Vector3.RIGHT, pulse * (0.26 if brace else 0.48))
			turn_world(rig, "bonel01", Vector3.UP, -0.42 * pulse)
			turn_world(rig, "boner01", Vector3.UP, 0.42 * pulse)
			for side: String in ["l", "r"]:
				turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, pulse * (-0.54 if brace else 0.15))
				turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, -0.27 * pulse)
		251:
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.12 * pulse)
			turn_world(rig, "bip01 neck", Vector3.RIGHT, -0.27 * pulse)
			turn_world(rig, "bip01 head", Vector3.UP, 0.40 * sway)
			turn_world(rig, "jawbone", Vector3.RIGHT, 0.12 * pulse)
		787:
			turn_world(rig, "spine 01", Vector3.RIGHT, -0.14 * pulse)
			turn_world(rig, "spine 03", Vector3.RIGHT, -0.15 * pulse)
			turn_world(rig, "head", Vector3.RIGHT, -0.29 * pulse)
			turn_world(rig, "antenna l 01", Vector3.RIGHT, 0.31 * pulse)
			turn_world(rig, "antenna r 01", Vector3.RIGHT, 0.31 * pulse)
			turn_world(rig, "large pincher l 01", Vector3.UP, -0.21 * pulse)
			turn_world(rig, "large pincher r 01", Vector3.UP, 0.21 * pulse)
		300:
			var hunch := slot == 15
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, pulse * (-0.23 if hunch else 0.12))
			turn_world(rig, "bip01 spine3", Vector3.UP, pulse * (-0.17 if hunch else 0.32 * sway))
			turn_world(rig, "bip01 neck1", Vector3.RIGHT, pulse * (0.14 if hunch else -0.18))
			turn_world(rig, "bip01 head", Vector3.UP, 0.22 * sway)
			turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.22 * pulse)
			turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.31 * pulse)
		263:
			turn_world(rig, "bip01 spine1", Vector3.UP, 0.24 * pulse)
			turn_world(rig, "bip01 head", Vector3.UP, 0.35 * sway)
			turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.29 * pulse)
			turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, 0.18 * pulse)
			turn_world(rig, "bip01 tail1", Vector3.UP, -0.38 * sway)
		253:
			var backswing := smoothstep(0.02, 0.28, phase) * (1.0 - smoothstep(0.30, 0.51, phase))
			turn_world(rig, "bip01 spine1", Vector3.UP, -0.25 * backswing + 0.34 * pulse)
			turn_world(rig, "bip01 head", Vector3.UP, 0.16 * pulse)
			turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.48 * pulse)
			turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.59 * pulse)
			turn_world(rig, "bip01 l forearm", Vector3.UP, -0.38 * backswing)
			turn_world(rig, "bip01 r forearm", Vector3.UP, -0.38 * backswing)
		305:
			var curl := slot == 15
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, pulse * (-0.12 if curl else 0.14))
			turn_world(rig, "bip01 spine3", Vector3.RIGHT, pulse * (-0.25 if curl else 0.16))
			turn_world(rig, "bip01 neck1", Vector3.RIGHT, pulse * (-0.22 if curl else 0.18))
			turn_world(rig, "bip01 neck3", Vector3.RIGHT, pulse * (-0.18 if curl else 0.13))
			turn_world(rig, "bip01 head", Vector3.RIGHT, 0.14 * pulse)
			turn_world(rig, "bip01 bone jaw2", Vector3.RIGHT, 0.20 * pulse)
