extends "res://Network/PreparedClassicActionsLive.gd"
## Sample each explicit fall before the native kill with both clients.

const FALLS := ["Death", "Death2", "AirDeath"]

func sample_additional_actions(sex: int) -> bool:
	var owned: Dictionary = death_arenas[sex].avatars
	if not check(owned.size() == 1, "One native subject for supplementary actions"):
		return false
	var serial: int = owned.keys()[0]
	var actors: Array[Node3D] = [owned[serial].horse_visual, death_arenas[1 - sex].avatars[serial].horse_visual]
	var row: Dictionary = actors[0].entry
	var slots: Array = row.native_extra_classic_actions
	var living: Array = []
	var groups: Array[Array] = [living]
	for value: Variant in slots:
		var slot := int(value)
		if row.classic_action_categories[str(slot)] in FALLS:
			groups.append([slot])
		else:
			living.append(slot)
	var actions: Array[Dictionary] = []
	for group: Array in groups:
		row.native_extra_classic_actions = group
		var passed := await super.sample_additional_actions(sex)
		row.native_extra_classic_actions = slots
		if not passed:
			return false
		actions.append_array(additional_actions[records.size()].actions)
		if group == living:
			continue
		for actor in actors:
			if not clear_fall(actor):
				return false
	additional_actions[records.size()].actions = actions
	return true

func clear_fall(actor: Node3D) -> bool:
	if actor.native_body in [73, 79]:
		if not check(actor.dead and not actor.collapse_skin.is_empty(), "Both clients arm support for the native fall"):
			return false
		actor.model.position -= actor.collapse_shift
		actor.collapse_shift = Vector3.ZERO
		actor.collapse_plane = {}
	else:
		if not check(actor.dead and not actor.fall.skin.is_empty(), "Both clients arm support for the native fall"):
			return false
		actor.model.position -= actor.fall.shift
		actor.fall.shift = Vector3.ZERO
		actor.fall.plane = {}
	actor.dead = false
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	return true
