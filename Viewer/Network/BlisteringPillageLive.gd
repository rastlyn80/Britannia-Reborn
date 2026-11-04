extends "res://Network/CreatureLive.gd"
## Use the pinned fixture recipe without changing the local active registry.

const INPUT := "res://../work/creatures/live-candidates.json"
const REPORT := "res://../outputs/creatures/blistering_pillage/live.json"

func _initialize() -> void:
	family = "blistering_pillage"
	create_timer(100.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string(INPUT))
	assert(candidates.size() == 1)
	var candidate: Dictionary = candidates[0]
	assert(candidate.body == 130 and candidate.native_class == "FireGargoyle")
	var row: Dictionary = candidate.presentation
	assert(row.status == "prepared" and row.kind == Registry.entry(130).kind)
	assert(row.classic_action_categories["11"] == "Pillage")
	for treatment in ["original", "rounded", "modern"]:
		var suffix: String = "" if treatment == "modern" else "-" + treatment
		var path := "res://local-art/creatures/gargoyle-130-pillage-trial%s.scn" % suffix
		assert(row.assets[treatment] == path and FileAccess.get_sha256(path) == row.authored_action_scene_sha256[treatment])
	Registry.entries[130] = row

	await super.run()
	if records.size() != 2 or accepted_pin != FileAccess.get_sha256("res://local-art/creatures/accepted-index.json"):
		return
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT))
	assert(report.records.size() == records.size() and report.candidate_sha256 == candidate_pin)
	report.prepared_trial = true
	report.prepared_wrapper_sha256 = FileAccess.get_sha256(get_script().resource_path)
	var output := FileAccess.open(REPORT, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
