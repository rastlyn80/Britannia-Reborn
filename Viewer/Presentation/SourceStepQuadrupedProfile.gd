# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Renderer := "res://Presentation/SourceLivingStepQuadrupedVisual.gd"
const Forms := {
	209: ["ruminants_goat_billy", ["GoatQuietStand"]],
	88: ["ruminants_goat_mountain", ["MountainGoatQuietStand"]],
	212: ["bruins_bear_grizzly", ["GrizzlyQuietStand", "GrizzlyScentTurn", "GrizzlyWakeAndRise"]],
	25: ["canines_wolf_grey_slot11_25", ["GreyWolfQuietStand", "GreyWolfScentWatch", "GreyWolfHowl", "GreyWolfEarAlert"]],
	27: ["canines_wolf_grey_slot11_27", []],
	203: ["porcines_pig", []],
	290: ["porcines_boar", ["BoarQuietStand", "BoarScentCheck", "BoarEarAlert"]],
}


static func enable() -> bool:
	var applied := 0
	for body: int in Forms:
		var original := Registry.entry(body)
		if not Registry.supports_body(body) or original.get("kind") != Forms[body][0]:
			continue
		if not matches_saved_scenes(original):
			continue
		var row := original.duplicate()
		row.presentation_script = Renderer
		row.step_idle_gestures = Forms[body][1]
		row.porcine_step_support = body in [203, 290]
		Registry.entries[body] = row
		applied += 1
	return applied == Forms.size()


static func matches_saved_scenes(row: Dictionary) -> bool:
	for style: String in ["original", "rounded", "modern"]:
		var asset := Registry.asset_path(row, style)
		var expected: String = row.get("asset_sha256", {}).get(style, "")
		if expected.length() != 64 or not ResourceLoader.exists(asset, "PackedScene"):
			return false
		if FileAccess.get_sha256(asset) != expected:
			return false
	return true
