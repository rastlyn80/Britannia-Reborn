extends "res://Network/PreparedClassicActionsLive.gd"

func sample_additional_actions(sex: int) -> bool:
	var owned: Dictionary = death_arenas[sex].avatars
	if not check(owned.size() == 1, "One native subject for supplementary actions"):
		return false
	var serial: int = owned.keys()[0]
	var actor: Node3D = owned[serial].horse_visual
	if actor.native_body != 124:
		return await super.sample_additional_actions(sex)
	var peer: Node3D = death_arenas[1 - sex].avatars[serial].horse_visual
	var row: Dictionary = actor.entry
	var slots: Array = row.native_extra_classic_actions
	var actions: Array[Dictionary] = []
	for group: Array in [[15, 16, 18], [2], [3]]:
		row.native_extra_classic_actions = group
		var passed := await super.sample_additional_actions(sex)
		row.native_extra_classic_actions = slots
		if not passed:
			return false
		actions.append_array(additional_actions[records.size()].actions)
		if group.size() == 1:
			for mage: Node3D in [actor, peer]:
				if not check(mage.dead and mage.current_clip == "Death", "Both exact Classic fall packets select the same archived mage fall"):
					return false
				mage.dead = false
				mage.action_remaining = 0.0
				mage.play_gait(false, 0.0)
	additional_actions[records.size()].actions = actions
	return true
