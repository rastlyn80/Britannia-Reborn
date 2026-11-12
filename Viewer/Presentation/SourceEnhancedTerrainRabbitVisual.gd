# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceTerrainRabbitVisual.gd"


func receive_action(request: Dictionary) -> bool:
	if request.get("protocol") == "new" and skeleton.has_node("NativeTunnelPose"):
		var kind := str(int(request.get("type", -1)))
		var modes: Dictionary = entry.get("enhanced_source_action_groups", {})
		if modes.get("0", {}).has(kind):
			return true
	return super.receive_action(request)
