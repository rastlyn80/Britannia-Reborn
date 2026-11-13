# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Creature := preload("res://Presentation/CreatureVisual.gd")
const Actions := preload("res://Presentation/EnhancedCreatureVariantActions.gd")
const MorphCastGestures := {1: "ChestBrace", 33: "Fidget", 51: "CrestRise", 54: "Fidget", 285: "ReaperLowGuard", 746: "MolochHighGuard", 747: "BansheeHandCheck", 748: "SpectralClutch"}

static func dispatch(avatar: Node3D, request: Dictionary, enhanced: bool, flags: int) -> bool:
	var visual: Node3D = avatar.horse_visual
	if visual is Creature and visual.action_profile == "monster" and visual.native_body == int(request.get("body", 0)) \
			and MorphCastGestures.has(visual.native_body) and is_monster_cast(request):
		var entry: Dictionary = visual.entry
		var groups: Dictionary = entry.get("classic_action_categories", {})
		var clip: String = MorphCastGestures[visual.native_body]
		if not visual.animator.has_animation(groups.get("12", "Cast")) and visual.animator.has_animation(clip):
			visual.entry = entry.merged({"classic_action_categories": groups.merged({"12": clip}, true)}, true)
			var played := Actions.dispatch(avatar, request, enhanced, flags)
			visual.entry = entry
			return played
	return Actions.dispatch(avatar, request, enhanced, flags)

static func is_monster_cast(request: Dictionary) -> bool:
	return request.get("protocol") == "classic" and int(request.get("action", -1)) == 12 \
		and int(request.get("frames", -1)) == 7 and int(request.get("repeat_count", -1)) == 1 \
		and request.get("reverse") == false and request.get("repeat") == false and int(request.get("delay", -1)) == 0
