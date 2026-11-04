extends "res://Network/OccurrenceDeathsLive.gd"
## Record the renderer used for the two explicit cat collapses.

func run() -> void:
	await super.run()
	if records.is_empty() or records.size() != additional_actions.size():
		return
	var path := "res://../outputs/creatures/%s/live.json" % family
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	report.renderer_sha256 = FileAccess.get_sha256("res://Presentation/SourceQuadrupedCollapseVisual.gd")
	report.field_renderer_sha256 = FileAccess.get_sha256("res://Presentation/FieldClassicCollapseVisual.gd")
	report.explicit_collapse_test_sha256 = FileAccess.get_sha256("res://Network/OccurrenceDeathsLive.gd")
	var output := FileAccess.open(path, FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
