# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-frost-through-gargoyle-actions.gd"

const HOLD_BODIES := [755, 754, 262]

func run() -> void:
	Registry.load_index()
	for body: int in HOLD_BODIES:
		var row := Registry.entry(body)
		assert(row.get("classic_gesture_batch") == "frost_through_gargoyle_actions" or body == 262)
		for treatment: String in row.assets:
			assert(row.asset_sha256[treatment] == FileAccess.get_sha256(row.assets[treatment]))
		fitting_body = body
		bake_body(body, "gargoyle-flight-minotaur-%d" % body, {} if body == 262 else {21: "AirDeath"},
			["bake-gargoyle-flight-minotaur-actions.gd", "bake-frost-through-gargoyle-actions.gd", "bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	assert(slot == 21)
	return fit_grounded(player, rig, skins, 1.10, "bip01", UPPER + STANCE + WINGS, hold_folded_wings, 0.008)

func hold_folded_wings(rig: Skeleton3D, phase: float) -> void:
	var drift := sin(phase * TAU) * 0.035
	turn_world(rig, WINGS[0], Vector3.UP, -0.19 - drift)
	turn_world(rig, WINGS[1], Vector3.UP, 0.19 + drift)
	turn_world(rig, WINGS[2], Vector3.RIGHT, -0.07)
	turn_world(rig, WINGS[3], Vector3.RIGHT, -0.07)
	turn_world(rig, "bip01 head", Vector3.RIGHT, 0.10 + drift)


