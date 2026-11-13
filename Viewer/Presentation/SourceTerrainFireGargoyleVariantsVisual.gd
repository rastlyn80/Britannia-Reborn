# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceTerrainFireGargoyleVisual.gd"

const VariantFall := preload("res://Presentation/FittedCreatureFallVariants.gd")


func receive_action(request: Dictionary) -> bool:
	if VariantFall.consume(self, request):
		return true
	return super.receive_action(request)


func begin_death_from(source: Node3D) -> float:
	if source.dead and source.current_clip in source.entry.get("enhanced_variant_falls", []):
		return VariantFall.handoff(self, source)
	return super.begin_death_from(source)
