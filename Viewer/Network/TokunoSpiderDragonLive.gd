extends "res://Network/PreparedClassicActionsLive.gd"
## Play each explicit fall in isolation before the fixture's ordinary kill.

const FALLS := ["Death", "Death2", "AirDeath"]

func sample_additional_actions(sex: int) -> bool:
	var owned: Dictionary = death_arenas[sex].avatars
	if not check(owned.size() == 1, "One native subject for supplementary actions"):
		return false
	var serial: int = owned.keys()[0]
	var actors: Array[Node3D] = [owned[serial].horse_visual, death_arenas[1 - sex].avatars[serial].horse_visual]
	var row: Dictionary = actors[0].entry
	var slots: Array = row.native_extra_classic_actions
	var gestures: Array[int] = []
	var falls: Array[int] = []
	for value: Variant in slots:
		var slot := int(value)
		if row.classic_action_categories[str(slot)] in FALLS:
			falls.append(slot)
		else:
			gestures.append(slot)
	if falls.is_empty():
		return await super.sample_additional_actions(sex)
	var actions: Array[Dictionary] = []
	var groups: Array = [gestures]
	for slot: int in falls:
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
			if not check(actor.dead and not actor.fall.skin.is_empty(), "Both clients arm support for the native fall"):
				return false
			actor.dead = false
			actor.action_remaining = 0.0
			actor.contact.enabled = true
			actor.model.position -= actor.fall.shift
			actor.fall.shift = Vector3.ZERO
			actor.fall.plane = {}
			actor.play_gait(false, 0.0)
	additional_actions[records.size()].actions = actions
	return true
