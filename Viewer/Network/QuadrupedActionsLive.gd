extends "res://Network/PreparedClassicActionsLive.gd"
## Witness separate quadruped actions before each real native death.

func run() -> void:
	await super.run()
	if records.is_empty() or records.size() != additional_actions.size():
		return
	var path := "res://../outputs/creatures/%s/live.json" % family
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	report.renderer_sha256 = FileAccess.get_sha256("res://Presentation/SourceQuadrupedCollapseVisual.gd")
	report.field_renderer_sha256 = FileAccess.get_sha256("res://Presentation/FieldClassicCollapseVisual.gd")
	report.supplemental_sha256 = FileAccess.get_sha256("res://Network/PreparedClassicActionsLive.gd")
	var output := FileAccess.open(path, FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()

func sample_additional_actions(sex: int) -> bool:
	var owned: Dictionary = death_arenas[sex].avatars
	if not check(owned.size() == 1, "One native quadruped for supplemental actions"):
		return false
	var serial: int = owned.keys()[0]
	var visuals: Array[Node] = [owned[serial].horse_visual, death_arenas[1 - sex].avatars[serial].horse_visual]
	var row: Dictionary = visuals[0].entry
	var slots: Array = row.native_extra_classic_actions
	var normal := slots.filter(func(slot: int) -> bool: return slot not in [8, 12])
	var actions: Array[Dictionary] = []
	for group: Array in [normal, [8], [12]]:
		row.native_extra_classic_actions = group
		var passed := await super.sample_additional_actions(sex)
		row.native_extra_classic_actions = slots
		if not passed:
			return false
		actions.append_array(additional_actions[records.size()].actions)
		if group[0] not in [8, 12]:
			continue
		for visual in visuals:
			if not check(visual.dead and not visual.collapse_skin.is_empty(), "Both clients prepare the skinned collapse"):
				return false
			visual.dead = false
			visual.action_remaining = 0.0
			visual.contact.enabled = true
			visual.collapse_plane = {}
	additional_actions[records.size()].actions = actions
	return true
