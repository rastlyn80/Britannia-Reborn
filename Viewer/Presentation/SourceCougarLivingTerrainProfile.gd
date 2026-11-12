# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Renderer := "res://Presentation/SourceLivingCougarVisual.gd"


static func enable() -> bool:
	var base := Registry.entry(63)
	if base.get("presentation_script") == Renderer:
		return true
	if base.get("kind") != "felines_cougar" or base.get("presentation_script") not in [
			"res://Presentation/SourceQuadrupedCollapseVisual.gd", "res://Presentation/SourceEnhancedFieldVisual.gd"]:
		return false
	for style: String in ["original", "rounded", "modern"]:
		var asset := Registry.asset_path(base, style)
		var expected: String = base.get("asset_sha256", {}).get(style, "")
		if expected.length() != 64 or not ResourceLoader.exists(asset, "PackedScene"):
			return false
		if FileAccess.get_sha256(asset) != expected:
			return false
	var row := base.duplicate(true)
	row["presentation_script"] = Renderer
	Registry.entries[63] = row
	return true
