extends "res://Network/PreparedClassicActionsLive.gd"
## Explicit alternate death packets on a living subject precede its real death.

func run() -> void:
	await super.run()
	if records.is_empty() or records.size() != additional_actions.size():
		return
	var path := "res://../outputs/creatures/%s/live.json" % family
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	report.collapse_sha256 = FileAccess.get_sha256("res://Presentation/SourceClassicCollapseVisual.gd")
	report.supplemental_sha256 = FileAccess.get_sha256("res://Network/PreparedClassicActionsLive.gd")
	var output := FileAccess.open(path, FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()

func sample_additional_actions(sex: int) -> bool:
	var owned: Dictionary = death_arenas[sex].avatars
	if not check(owned.size() == 1, "One fixture creature for both explicit collapses"):
		return false
	var serial: int = owned.keys()[0]
	var visuals: Array[Node] = [owned[serial].horse_visual, death_arenas[1 - sex].avatars[serial].horse_visual]
	var row: Dictionary = visuals[0].entry
	var slots: Array = row.native_extra_classic_actions
	var actions: Array[Dictionary] = []
	for slot: int in slots:
		row.native_extra_classic_actions = [slot]
		var passed := await super.sample_additional_actions(sex)
		row.native_extra_classic_actions = slots
		if not passed:
			return false
		if not check(visuals.all(func(visual: Node) -> bool: return visual.dead), "Both explicit collapses enter the death state"):
			return false
		actions.append_array(additional_actions[records.size()].actions)
		for visual in visuals:
			visual.dead = false
			visual.action_remaining = 0.0
			visual.collapse_plane = {}
			visual.contact.enabled = true
	additional_actions[records.size()].actions = actions
	return true
