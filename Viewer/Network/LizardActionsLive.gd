extends "res://Network/PreparedClassicActionsLive.gd"
## Witness explicit collapses before the server kills the armed fixture.

func run() -> void:
	await super.run()
	if records.is_empty() or records.size() != additional_actions.size():
		return
	var path := "res://../outputs/creatures/%s/live.json" % family
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	report.renderer_sha256 = FileAccess.get_sha256("res://Presentation/SourceLizardActionsVisual.gd")
	report.armed_renderer_sha256 = FileAccess.get_sha256("res://Presentation/SourceArmedLizardmanVisual.gd")
	report.supplemental_sha256 = FileAccess.get_sha256("res://Network/PreparedClassicActionsLive.gd")
	var output := FileAccess.open(path, FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()

func sample_additional_actions(sex: int) -> bool:
	var owned: Dictionary = death_arenas[sex].avatars
	if not check(owned.size() == 1, "One native armed Lizardman for supplemental actions"):
		return false
	var serial: int = owned.keys()[0]
	var visuals: Array[Node] = [owned[serial].horse_visual, death_arenas[1 - sex].avatars[serial].horse_visual]
	var row: Dictionary = visuals[0].entry
	var slots: Array = row.native_extra_classic_actions
	var actions: Array[Dictionary] = []
	for group: Array in [[10, 15, 16], [2], [3]]:
		row.native_extra_classic_actions = group
		var passed := await super.sample_additional_actions(sex)
		row.native_extra_classic_actions = slots
		if not passed:
			return false
		actions.append_array(additional_actions[records.size()].actions)
		if group.size() != 1:
			continue
		for visual in visuals:
			if not check(visual.dead and visual.death_skin.size() == 2, "Both clients track the armed body and weapon during collapse"):
				return false
			visual.dead = false
			visual.action_remaining = 0.0
			visual.contact.enabled = true
			visual.model.transform = visual.death_model
			visual.death_skin.clear()
	additional_actions[records.size()].actions = actions
	return true
