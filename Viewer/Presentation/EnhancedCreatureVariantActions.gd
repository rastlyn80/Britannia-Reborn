# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
const Attack := preload("res://Presentation/EnhancedCreatureAttackActions.gd")
const Creature := preload("res://Presentation/CreatureVisual.gd")


static func dispatch(avatar: Node3D, request: Dictionary, enhanced: bool, flags: int) -> bool:
	var actor: Node3D = avatar.horse_visual
	if not enhanced or not is_instance_valid(actor) or flags < 0 or request.get("protocol") != "new":
		return Attack.dispatch(avatar, request, enhanced, flags)
	var variant: int = request.get("variation", -1)
	if variant < 0 or variant > 127 or not actor is Creature or actor.native_body != int(request.get("body", 0)):
		return Attack.dispatch(avatar, request, enhanced, flags)
	var kind: int = request.get("type", -1)
	var entry: Dictionary = actor.entry
	var falls: Array = entry.get("enhanced_variant_falls", [])
	if kind == 3 and not falls.is_empty():
		var clip: String = falls[variant % falls.size()]
		if clip == entry.get("enhanced_nonfatal_death_choice", ""):
			return Attack.dispatch(avatar, request, enhanced, flags)
		actor.entry = entry.merged({"enhanced_selected_fall": clip}, true)
		var accepted: bool = avatar.receive_native_action(request)
		actor.entry = entry
		return accepted
	if kind == 0 and variant == 1 and actor.native_body in [730, 734] and not falls.is_empty():
		var attacks: Dictionary = entry["enhanced_attack_subactions"]
		var sub := str(int(request.get("subaction", 0)) & 255)
		var choices: Array = attacks.get(sub, attacks["255"])
		var clip: String = choices[variant % choices.size()]
		actor.entry = entry.merged({"new_action_categories": entry.get("new_action_categories", {}).merged({"0": clip}, true)}, true)
		var accepted: bool = avatar.receive_native_action(request.merged({"variation": 0}, true))
		actor.entry = entry
		if accepted:
			actor.set_meta("native_action", request.duplicate(true))
		return accepted
	return Attack.dispatch(avatar, request, enhanced, flags)
