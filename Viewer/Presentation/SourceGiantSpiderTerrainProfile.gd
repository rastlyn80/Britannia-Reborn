# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Body := 28
const Base := "res://Presentation/GiantSpiderActionsVisual.gd"
const Renderer := "res://Presentation/SourceLivingGiantSpiderVisual.gd"


static func enable() -> bool:
	var row := Registry.entry(Body)
	if not Registry.supports_body(Body) or row.get("presentation_script") not in [Base, Renderer]:
		return false
	if row.presentation_script == Base:
		var active := row.duplicate()
		active.presentation_script = Renderer
		Registry.entries[Body] = active
	return true
