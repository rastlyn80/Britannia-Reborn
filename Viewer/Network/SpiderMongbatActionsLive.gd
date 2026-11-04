extends "res://Network/PreparedClassicActionsLive.gd"
## Witness the explicit ground and air collapses before the native kill.

const RENDERERS := [preload("res://Presentation/GiantSpiderActionsVisual.gd"),
	preload("res://Presentation/MongbatActionsVisual.gd")]

func run() -> void:
	await super.run()
	if records.is_empty() or records.size() != additional_actions.size():
		return
	var path := "res://../outputs/creatures/%s/live.json" % family
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var dependencies := {}
	for renderer: Script in RENDERERS:
		dependencies[renderer.resource_path.get_file().get_basename()] = FileAccess.get_sha256(renderer.resource_path)
	for name: String in ["SourceQuadrupedCollapseVisual", "FieldClassicCollapseVisual", "SourceGroundedGestureVisual", "SourceGroundLookup"]:
		dependencies[name] = FileAccess.get_sha256("res://Presentation/%s.gd" % name)
	report.collapse_renderers = dependencies
	report.supplemental_sha256 = FileAccess.get_sha256("res://Network/PreparedClassicActionsLive.gd")
	var output := FileAccess.open(path, FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()

func sample_additional_actions(sex: int) -> bool:
	var owned: Dictionary = death_arenas[sex].avatars
	if not check(owned.size() == 1, "One native Spider or Mongbat for supplementary actions"):
		return false
	var serial: int = owned.keys()[0]
	var visuals: Array[Node] = [owned[serial].horse_visual, death_arenas[1 - sex].avatars[serial].horse_visual]
	var row: Dictionary = visuals[0].entry
	var slots: Array = row.native_extra_classic_actions
	var living: Array[int] = []
	var collapses: Array[int] = []
	for value: Variant in slots:
		var slot := int(value)
		if row.classic_action_categories[str(slot)] in ["Death", "Death2", "AirDeath"]:
			collapses.append(slot)
		else:
			living.append(slot)
	if not check(not living.is_empty() and collapses.size() == (3 if int(row.bodies[0].body) == 39 else 2),
			"All native collapse variants are requested"):
		return false
	var groups: Array = [living]
	for slot: int in collapses:
		groups.append([slot])
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
		for visual in visuals:
			if not check(visual.dead and not visual.collapse_skin.is_empty(), "Both clients track the skinned collapse"):
				return false
			visual.dead = false
			visual.action_remaining = 0.0
			visual.contact.enabled = true
			visual.model.position -= visual.collapse_shift
			visual.collapse_shift = Vector3.ZERO
			visual.collapse_plane = {}
			visual.play_gait(false, 0.0)
	additional_actions[records.size()].actions = actions
	return true
