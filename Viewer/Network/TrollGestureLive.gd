extends "res://Network/CreatureLive.gd"
## Exercise the checked Troll packages without replacing the active registry on disk.

const INPUT := "res://../work/creatures/live-candidates.json"
const REPORT := "res://../outputs/creatures/troll_gestures/live.json"
const FORMS := {
	53: ["Troll", "troll-53-armed-trial"],
	54: ["Troll", "trolls_troll-slot11-trial"],
	55: ["FrostTroll", "troll-55-armed-trial"],
}

func _initialize() -> void:
	family = "troll_gestures"
	create_timer(150.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string(INPUT))
	assert(candidates.size() == FORMS.size())
	Registry.load_index()
	for candidate: Dictionary in candidates:
		var body := int(candidate.body)
		var form: Array = FORMS[body]
		var row: Dictionary = candidate.presentation
		assert(candidate.native_class == form[0] and row.status == "prepared")
		assert(row.kind == Registry.entry(body).kind and row.bodies.size() == 1 and row.bodies[0].body == body)
		assert(row.classic_action_categories["11"] == "KneelingSwing")
		assert(row.presentation_script == "res://Presentation/SourceArmedLizardmanVisual.gd")
		assert(FileAccess.get_sha256(row.presentation_script) == row.presentation_script_sha256)
		for treatment in ["original", "rounded", "modern"]:
			var suffix: String = "" if treatment == "modern" else "-" + treatment
			var path := "res://local-art/creatures/%s%s.scn" % [form[1], suffix]
			assert(row.assets[treatment] == path and FileAccess.get_sha256(path) == row.authored_action_scene_sha256[treatment])
		Registry.entries[body] = row

	await super.run()
	if records.size() != FORMS.size() * 2 or accepted_pin != FileAccess.get_sha256("res://local-art/creatures/accepted-index.json"):
		return
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT))
	assert(report.records.size() == records.size() and report.candidate_sha256 == candidate_pin)
	report.prepared_trial = true
	report.prepared_wrapper_sha256 = FileAccess.get_sha256(get_script().resource_path)
	var output := FileAccess.open(REPORT, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
