# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Creature := preload("res://Presentation/CreatureVisual.gd")
const ROUTES_PATH := "res://Presentation/creature-wire-routes.json"
static var routes: Dictionary

static func dispatch(avatar: Node3D, request: Dictionary) -> bool:
	var visual: Node3D = avatar.horse_visual
	if request.get("protocol") != "new" or int(request.get("subaction", -1)) != 0 or not visual is Creature:
		return avatar.receive_native_action(request)
	var body := str(int(request.get("body", 0)))
	var kind := str(int(request.get("type", -1)))
	if body != str(visual.native_body):
		return avatar.receive_native_action(request)
	var entry: Dictionary = visual.entry
	var overrides: Dictionary = entry.get("new_action_categories", {})
	if overrides.has(kind):
		return avatar.receive_native_action(request)
	if routes.is_empty():
		routes = JSON.parse_string(FileAccess.get_file_as_string(ROUTES_PATH))
	var rule: Array = routes.get(body, {}).get(kind, [])
	if rule.is_empty():
		return avatar.receive_native_action(request)
	var parity := int(request.get("variation", 0)) & 1
	var group := str(int(rule[parity]))
	var fallback := str(rule[2 + parity] if rule.size() == 4 else rule[2])
	var body_groups: Dictionary = entry.get("classic_action_categories_by_body", {}).get(body, {})
	var shared_groups: Dictionary = entry.get("classic_action_categories", {})
	var clip := str(body_groups.get(group, shared_groups.get(group, fallback)))
	if not visual.animator.has_animation(clip):
		clip = fallback
	# Give the renderer a per-call type override while retaining the original
	# packet, timing, dispatch and metadata. Other bodies may share this row.
	visual.entry = entry.duplicate()
	visual.entry["new_action_categories"] = overrides.merged({kind: clip})
	var played: bool = avatar.receive_native_action(request)
	visual.entry = entry
	return played
