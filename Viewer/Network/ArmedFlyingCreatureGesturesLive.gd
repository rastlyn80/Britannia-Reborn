extends "res://Network/PreparedClassicActionsLive.gd"

func sample_additional_actions(sex: int) -> bool:
	var owned: Dictionary = death_arenas[sex].avatars
	if not check(owned.size() == 1, "One native subject for supplementary actions"):
		return false
	var serial: int = owned.keys()[0]
	var actor: Node3D = owned[serial].horse_visual
	if actor.native_body != 40:
		return await super.sample_additional_actions(sex)
	var peer: Node3D = death_arenas[1 - sex].avatars[serial].horse_visual
	var row: Dictionary = actor.entry
	var slots: Array = row.native_extra_classic_actions
	var actions: Array[Dictionary] = []
	for group: Array in [[10, 13, 15, 16, 18], [2], [3], [21]]:
		row.native_extra_classic_actions = group
		var passed := await super.sample_additional_actions(sex)
		row.native_extra_classic_actions = slots
		if not passed:
			return false
		actions.append_array(additional_actions[records.size()].actions)
		if group.size() == 1:
			for balron: Node3D in [actor, peer]:
				if not check(balron.dead and not balron.fall.skin.is_empty(), "The native Balron fall arms terrain support"):
					return false
				balron.dead = false
				balron.action_remaining = 0.0
				balron.contact.enabled = true
				balron.model.position -= balron.fall.shift
				balron.fall.shift = Vector3.ZERO
				balron.fall.plane = {}
				balron.play_gait(false, 0.0)
	additional_actions[records.size()].actions = actions
	return true
