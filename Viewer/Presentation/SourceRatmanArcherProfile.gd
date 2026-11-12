# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Archer := preload("res://Presentation/SourceRatmanArcherVisual.gd")
const Renderer := "res://Presentation/SourceRatmanArcherVisual.gd"


static func enable() -> bool:
	var base := Registry.entry(142)
	if base.get("presentation_script") == Renderer:
		return true
	if base.get("kind") != "rat_race_ratman" or not Registry.supports_body(142) or not Archer.prepare_bow():
		return false
	var row := base.duplicate(true)
	row["presentation_script"] = Renderer
	Registry.entries[142] = row
	return true
