# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Enhanced := "res://Presentation/SourceEnhancedSkeletonVisual.gd"
const Armed := "res://Presentation/SourceArmedLizardmanVisual.gd"
const Living := "res://Presentation/SourceLivingSkeletonVisual.gd"
const EnhancedLiving := "res://Presentation/SourceTerrainEnhancedSkeletonVisual.gd"


static func enable() -> bool:
	var enabled := 0
	for body: int in [50, 56]:
		var entry := Registry.entry(body)
		if not Registry.supports_body(body) or not str(entry.get("kind", "")).begins_with("skeletons_skeleton"):
			continue
		var renderer: String = entry.get("presentation_script", "")
		if renderer not in ["", Armed, Enhanced, Living, EnhancedLiving]:
			continue
		if renderer not in [Living, EnhancedLiving]:
			var active := entry.duplicate()
			active.presentation_script = EnhancedLiving if renderer == Enhanced else Living
			Registry.entries[body] = active
		enabled += 1
	return enabled == 2
