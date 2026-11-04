extends "res://Network/PreparedClassicActionsLive.gd"
## Request each explicit fall separately before the ordinary native kill.

func sample_additional_actions(sex: int) -> bool:
	var owned: Dictionary = death_arenas[sex].avatars
	if not check(owned.size() == 1, "One native subject for supplementary actions"):
		return false
	var serial: int = owned.keys()[0]
	var actors: Array[Node] = [owned[serial].horse_visual, death_arenas[1 - sex].avatars[serial].horse_visual]
	var row: Dictionary = actors[0].entry
	var slots: Array = row.native_extra_classic_actions
	var collapses: Array[int] = []
	var gestures: Array[int] = []
	for value: Variant in slots:
		var slot := int(value)
		if row.classic_action_categories[str(slot)] in ["Death", "Death2", "AirDeath"]:
			collapses.append(slot)
		else:
			gestures.append(slot)
	var expected := [8, 12] if int(row.bodies[0].body) == 213 else [2, 3, 21]
	if not check(collapses == expected and not gestures.is_empty(), "Exact ground and air collapse groups for this body"):
		return false
	var actions: Array[Dictionary] = []
	var groups: Array = [gestures]
	for slot: int in collapses:
		groups.append([slot])
	for group: Array in groups:
		row.native_extra_classic_actions = group
		var passed := await super.sample_additional_actions(sex)
		row.native_extra_classic_actions = slots
		if not passed:
			return false
		actions.append_array(additional_actions[records.size()].actions)
		if group == gestures:
			continue
		for actor in actors:
			if not check(actor.dead and not actor.collapse_skin.is_empty(), "Both clients retain skinned support for the native fall"):
				return false
			actor.dead = false
			actor.action_remaining = 0.0
			actor.contact.enabled = true
			actor.model.position -= actor.collapse_shift
			actor.collapse_shift = Vector3.ZERO
			actor.collapse_plane = {}
			actor.play_gait(false, 0.0)
	additional_actions[records.size()].actions = actions
	return true
