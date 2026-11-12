# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Renderer := "res://Presentation/SourceLivingTrollVisual.gd"
const Bases := [
	"res://Presentation/SourceLizardActionsVisual.gd",
	"res://Presentation/SourceEnhancedTrollVisual.gd",
	"res://Presentation/SourceEnhancedFrostTrollVisual.gd",
]
const Forms := {53: "trolls_troll_slot11_53", 54: "trolls_troll_slot11_54", 55: "trolls_troll_frost"}


static func enable() -> bool:
	var enabled := 0
	for body: int in Forms:
		var base := Registry.entry(body)
		if base.get("presentation_script") == Renderer:
			enabled += 1
			continue
		if base.get("kind") != Forms[body] or base.get("presentation_script") not in Bases:
			continue
		if not matches_saved_scenes(base):
			continue
		var row := base.duplicate(true)
		row["presentation_script"] = Renderer
		Registry.entries[body] = row
		enabled += 1
	return enabled == Forms.size()


static func matches_saved_scenes(row: Dictionary) -> bool:
	for style: String in ["original", "rounded", "modern"]:
		var asset := Registry.asset_path(row, style)
		var expected: String = row.get("asset_sha256", {}).get(style, "")
		if expected.length() != 64 or not ResourceLoader.exists(asset, "PackedScene") \
				or FileAccess.get_sha256(asset) != expected:
			return false
	return true
