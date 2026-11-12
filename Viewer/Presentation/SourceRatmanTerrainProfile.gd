# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Classic := "res://Presentation/SourceLivingRatmanVisual.gd"
const Renderers := {
	"": Classic,
	"res://Presentation/SourceQuadrupedCollapseVisual.gd": Classic,
	"res://Presentation/SourceRatmanArcherVisual.gd": "res://Presentation/SourceTerrainRatmanArcherVisual.gd",
	"res://Presentation/SourceEnhancedRatmanVisual.gd": "res://Presentation/SourceTerrainEnhancedRatmanVisual.gd",
	"res://Presentation/RatmanMageActionsVisual.gd": "res://Presentation/SourceTerrainRatmanMageVisual.gd",
	"res://Presentation/SourceEnhancedRatmanMageVisual.gd": "res://Presentation/SourceTerrainEnhancedRatmanMageVisual.gd",
}


static func enable() -> void:
	for body: int in [42, 44, 45, 142, 143]:
		var base := Registry.entry(body)
		var renderer: String = base.get("presentation_script", "")
		if not Renderers.has(renderer) or not Registry.supports_body(body):
			continue
		if renderer in ["", "res://Presentation/SourceQuadrupedCollapseVisual.gd"] and not str(base.get("kind", "")).begins_with("rat_race_ratman"):
			continue
		var row := base.duplicate(true)
		row["presentation_script"] = Renderers[renderer]
		Registry.entries[body] = row
