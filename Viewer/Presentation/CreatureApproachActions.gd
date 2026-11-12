# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Creature := preload("res://Presentation/CreatureVisual.gd")
const Actions := preload("res://Presentation/EnhancedCreatureAttackActions.gd")
const Bodies := [8, 22, 49, 66, 89, 94, 106, 107, 108, 109, 110, 111, 112, 113, 129, 135, 142, 147,
	166, 168, 180, 206, 215, 790]


static func dispatch(avatar: Node3D, request: Dictionary, enhanced: bool, flags: int) -> bool:
	var visual: Node3D = avatar.horse_visual
	if visual is Creature and visual.action_profile == "monster" and visual.native_body in Bodies \
			and int(request.get("body", 0)) == visual.native_body and is_stock_approach(request):
		var groups: Dictionary = visual.entry.get("classic_action_categories", {})
		var overrides: Dictionary = visual.entry.get("classic_action_categories_by_body", {}).get(str(visual.native_body), {})
		var notice: String = overrides.get("11", groups.get("11", "Pillage"))
		if not visual.animator.has_animation(notice):
			var accepted: bool = avatar.receive_native_action(request.merged({"action": 18}, true))
			if accepted:
				visual.set_meta("native_action", request.duplicate(true))
			return accepted
	return Actions.dispatch(avatar, request, enhanced, flags)


static func is_stock_approach(request: Dictionary) -> bool:
	return request.get("protocol") == "classic" and int(request.get("action", -1)) == 11 \
		and int(request.get("frames", -1)) == 5 and int(request.get("repeat_count", -1)) == 1 \
		and request.get("reverse") == false and request.get("repeat") == false and int(request.get("delay", -1)) == 1
