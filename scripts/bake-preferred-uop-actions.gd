# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const UOP_FITS := {
	753: {15: "UopGargoyleGuard", 23: "UopGargoyleStand", 27: "UopGargoyleLunge", 28: "UopGargoyleStep"},
	831: {26: "UopParrotWingTuck"},
}
const UOP_PINS := "res://../scripts/preferred-uop-action-pins.json"
var pins: Dictionary

const UOP_BIPED := ["bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 head",
	"bip01 l upperarm", "bip01 l forearm", "bip01 r upperarm", "bip01 r forearm",
	"bip01 l thigh", "bip01 l calf", "bip01 r thigh", "bip01 r calf"]
const UOP_WINGS := ["gargoyle l mainwing1", "gargoyle r mainwing1"]
const UOP_BIRD := ["bip01 head", "bip01 neck1", "bip01 l forearm", "bip01 r forearm", "bip01 tail"]

func run() -> void:
	Registry.load_index()
	pins = JSON.parse_string(FileAccess.get_file_as_string(UOP_PINS)).bodies
	for body: int in UOP_FITS:
		var row := Registry.entry(body).duplicate(true)
		var assets := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var base_assets: Dictionary = row.get("preferred_uop_base_assets", row.assets)
			var path: String = base_assets[treatment]
			var hashes: Dictionary = row.get("preferred_uop_base_sha256", row.get("asset_sha256", row.authored_action_scene_sha256))
			assert(FileAccess.get_sha256(path) == hashes[treatment])
			assets[treatment] = path
		row.assets = assets
		Registry.entries[body] = row
		fitting_body = body
		bake_body(body, "preferred-uop-%d" % body, UOP_FITS[body],
			["bake-preferred-uop-actions.gd", "preferred-uop-action-pins.json",
				"bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	var heights: Array = pins[str(fitting_body)].frames[str(slot)].median_registered_height
	var duration := 0.10 * (heights.size() - 1)
	var joints := UOP_BIRD if fitting_body == 831 else UOP_BIPED + (UOP_WINGS if fitting_body == 753 else [])
	return fit_grounded(player, rig, skins, duration, "bip01", joints, pose_uop.bind(slot, heights), 0.006)

func pose_uop(rig: Skeleton3D, phase: float, slot: int, heights: Array) -> void:
	var step := phase * (heights.size() - 1)
	var lower := mini(floori(step), heights.size() - 2)
	var height := lerpf(heights[lower], heights[lower + 1], smoothstep(0.0, 1.0, step - lower))
	var sway := sin(phase * TAU)
	var reach := smoothstep(0.07, 0.47, phase) * (1.0 - smoothstep(0.63, 0.98, phase))
	if fitting_body == 831:
		var tuck := (16.0 - height) * 0.19
		turn_world(rig, "bip01 neck1", Vector3.RIGHT, -0.19 * reach)
		turn_world(rig, "bip01 head", Vector3.UP, 0.11 * sway * reach)
		turn_world(rig, "bip01 l forearm", Vector3.FORWARD, tuck)
		turn_world(rig, "bip01 r forearm", Vector3.FORWARD, -tuck)
		turn_world(rig, "bip01 tail", Vector3.RIGHT, 0.14 * reach)
		return
	var compress := clampf((66.0 - height) / 30.0, -0.23, 1.0)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, 0.33 * compress)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.28 * compress)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -0.31 * compress)
	for side: String in ["l", "r"]:
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, 0.34 * compress)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, -0.50 * compress)
	var lunge := reach if slot in [15, 27, 28] else 0.0
	turn_world(rig, "bip01 spine2", Vector3.UP, 0.29 * lunge)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.75 * lunge - 0.21 * compress)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.35 * lunge)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.31 * lunge - 0.17 * compress)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -0.26 * lunge)
	turn_world(rig, "bip01 l thigh", Vector3.RIGHT, -0.28 * lunge)
	turn_world(rig, "bip01 r thigh", Vector3.RIGHT, 0.22 * lunge)
	turn_world(rig, UOP_WINGS[0], Vector3.UP, 0.14 * compress + 0.10 * lunge)
	turn_world(rig, UOP_WINGS[1], Vector3.UP, -0.14 * compress - 0.10 * lunge)
