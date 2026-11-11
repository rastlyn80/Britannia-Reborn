# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Dispatch := preload("res://Presentation/EnhancedCreatureActions.gd")
const Creature := preload("res://Presentation/CreatureVisual.gd")


static func dispatch(avatar: Node3D, request: Dictionary, enhanced: bool, flags: int) -> bool:
	var visual: Node3D = avatar.horse_visual
	if not enhanced or not visual is Creature or request.get("protocol") != "new" 			or int(request.get("type", -1)) != 0:
		return Dispatch.dispatch(avatar, request, enhanced, flags)
	var entry: Dictionary = visual.entry
	var attacks: Dictionary = entry.get("enhanced_attack_subactions", {})
	if attacks.is_empty():
		return Dispatch.dispatch(avatar, request, enhanced, flags)
	# The Enhanced selector reads the low byte of the wire subaction. Peace
	# has no attack table for this body and inherits the combat choices.
	var subaction := str(int(request.get("subaction", -1)) & 0xff)
	var choices: Array = attacks.get(subaction, attacks["255"])
	visual.entry = entry.merged({"enhanced_source_action_groups": {"0": {"0": choices}}}, true)
	var accepted := Dispatch.dispatch(avatar, request, enhanced, flags)
	visual.entry = entry
	return accepted
