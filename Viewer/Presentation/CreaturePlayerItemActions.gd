# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Creature := preload("res://Presentation/CreatureVisual.gd")
const Cast := preload("res://Presentation/CreatureMorphCastActions.gd")
const Assets := "res://local-art/creatures/player-item-actions"
const DaggerBodies := [1, 33, 51, 54]


static func dispatch(avatar: Node3D, request: Dictionary, enhanced: bool, flags: int) -> bool:
	var visual: Node3D = avatar.horse_visual
	if visual is Creature and visual.action_profile == "monster" and visual.native_body == int(request.get("body", 0)):
		var clip := item_clip(visual.native_body, request)
		if not clip.is_empty() and load_clip(visual, clip):
			var entry: Dictionary = visual.entry
			var groups: Dictionary = entry.get("classic_action_categories", {})
			visual.entry = entry.merged({"classic_action_categories": groups.merged({str(request.action): clip}, true)}, true)
			var played: bool = avatar.receive_native_action(request)
			visual.entry = entry
			if played:
				return true
	return Cast.dispatch(avatar, request, enhanced, flags)


static func item_clip(body: int, request: Dictionary) -> String:
	if request.get("protocol") != "classic" or request.get("repeat_count") != 1 \
			or request.get("reverse") != false or request.get("repeat") != false or request.get("delay") != 0:
		return ""
	if request.get("action") == 9 and request.get("frames") in [1, 7] and body in DaggerBodies:
		return "CreatureDaggerThrow"
	if request.get("action") == 11 and request.get("frames") == 5 and body == 33:
		return "CreatureBolaThrow"
	return ""


static func load_clip(visual: Node3D, clip: String) -> bool:
	var player: AnimationPlayer = visual.animator
	if player.has_animation(clip):
		return true
	var path := Assets.path_join("%d-%s-%s.res" % [visual.native_body, visual.treatment, clip])
	if not ResourceLoader.exists(path, "Animation"):
		return false
	var animation := load(path) as Animation
	var animation_root := player.get_node_or_null(player.root_node)
	if animation == null or animation_root == null:
		return false
	for index in animation.get_track_count():
		var channel := animation.track_get_path(index)
		if animation_root.get_node_or_null(NodePath(channel.get_concatenated_names())) != visual.skeleton \
				or channel.get_subname_count() != 1 or visual.skeleton.find_bone(channel.get_subname(0)) < 0:
			return false
	var library := player.get_animation_library("").duplicate() as AnimationLibrary
	if library.add_animation(clip, animation) != OK:
		return false
	player.remove_animation_library("")
	return player.add_animation_library("", library) == OK
