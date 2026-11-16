# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Body := 214
const PredatorBody := 127
const Renderer := "res://Presentation/SourceLivingCougarVisual.gd"
const Previous := "res://Presentation/SourceQuadrupedCollapseVisual.gd"


static func enable() -> bool:
	enable_body(PredatorBody, "felines_predator_hellcat", "")
	return enable_body(Body, "felines_panther", Previous)


static func enable_body(body: int, kind: String, previous: String) -> bool:
	var base := Registry.entry(body)
	if base.get("presentation_script") == Renderer:
		return true
	if base.get("kind") != kind or base.get("presentation_script", "") != previous:
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
	Registry.entries[body] = row
	return true
