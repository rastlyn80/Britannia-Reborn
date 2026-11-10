# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Creature := preload("res://Presentation/CreatureVisual.gd")
const Classic := preload("res://Presentation/NativeMobileActions.gd")

static func dispatch(avatar: Node3D, request: Dictionary, enhanced: bool, native_flags: int) -> bool:
	var visual: Node3D = avatar.horse_visual
	if enhanced and native_flags >= 0 and visual is Creature and request.get("protocol") == "new":
		var variant := int(request.get("variation", -1))
		var body := int(request.get("body", 0))
		if variant >= 0 and variant <= 127 and visual.native_body == body:
			var entry: Dictionary = visual.entry
			var type := str(int(request.get("type", -1)))
			var prepared: Dictionary = entry.get("enhanced_source_action_groups", {})
			var mode := "1" if (native_flags & 0x40) == 0 else "0"
			if (native_flags & 0x04) != 0 and (body == 831 or entry.get("flight_falls_back_to_combat", false)):
				# The negotiated 7.x mobile flags carry flight on bit 2.
				mode = "0"
			var mode_groups: Dictionary = prepared.get(mode, {})
			var combat_groups: Dictionary = prepared.get("0", {})
			var clips: Array = mode_groups.get(type, combat_groups.get(type, []))
			if not clips.is_empty():
				var clip: String = clips[variant % clips.size()]
				if visual.animator.has_animation(clip):
					var overrides: Dictionary = entry.get("new_action_categories", {})
					visual.entry = entry.merged({"new_action_categories": overrides.merged({type: clip}, true)}, true)
					var accepted: bool = avatar.receive_native_action(request)
					visual.entry = entry
					return accepted
	return Classic.dispatch(avatar, request)
