extends "res://Network/PreparedClassicActionsLive.gd"
## Check requested collapses separately before the real native death.

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
	if not check(owned.size() == 1, "One native subject for supplementary actions"):
		return false
	var serial: int = owned.keys()[0]
	var visuals: Array[Node] = [owned[serial].horse_visual, death_arenas[1 - sex].avatars[serial].horse_visual]
	var row: Dictionary = visuals[0].entry
	var slots: Array = row.native_extra_classic_actions
	var collapse: Array[int] = []
	var living: Array[int] = []
	for value: Variant in slots:
		var slot := int(value)
		if row.classic_action_categories[str(slot)] in ["Death", "Death2"]:
			collapse.append(slot)
		else:
			living.append(slot)
	if not check(collapse.size() == 2 and not living.is_empty(), "Two collapse groups and living actions"):
		return false
	var actions: Array[Dictionary] = []
	for group: Array in [living, [collapse[0]], [collapse[1]]]:
		row.native_extra_classic_actions = group
		var passed := await super.sample_additional_actions(sex)
		row.native_extra_classic_actions = slots
		if not passed:
			return false
		actions.append_array(additional_actions[records.size()].actions)
		if group == living:
			continue
		for visual in visuals:
			if not check(visual.dead and not visual.collapse_skin.is_empty(), "Both clients track the skinned collapse"):
				return false
			visual.dead = false
			visual.action_remaining = 0.0
			visual.contact.enabled = true
			visual.collapse_plane = {}
	additional_actions[records.size()].actions = actions
	return true
