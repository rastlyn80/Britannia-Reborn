extends "res://Network/CreatureLive.gd"
## The owned recipe is verified by the fixture builder before server startup.

const INPUT := "res://../work/creatures/live-candidates.json"
const MANIFEST := "res://../scripts/classic-gesture-inputs.json"
const REPORT := "res://../outputs/creatures/classic_gestures/live.json"

func _initialize() -> void:
	family = "classic_gestures"
	create_timer(150.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string(INPUT))
	var recipes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var count := 0
	for recipe: Dictionary in recipes.values():
		count += recipe.classes.size()
	assert(candidates.size() == count)
	Registry.load_index()
	for candidate: Dictionary in candidates:
		var body := int(candidate.body)
		var recipe: Dictionary = recipes[str(body)]
		var row: Dictionary = candidate.presentation
		assert(candidate.native_class in recipe.classes and row.status == "prepared")
		assert(row.kind == Registry.entry(body).kind and row.bodies.size() == 1 and row.bodies[0].body == body)
		assert(row.classic_action_categories["11"] == recipe.clip)
		assert(row.authored_action_reference == recipe.directional_payload_sha256)
		for treatment in ["original", "rounded", "modern"]:
			var suffix: String = "" if treatment == "modern" else "-" + treatment
			var path := "res://local-art/creatures/slot11-%d-trial%s.scn" % [body, suffix]
			assert(row.assets[treatment] == path and FileAccess.get_sha256(path) == row.authored_action_scene_sha256[treatment])
		Registry.entries[body] = row

	await super.run()
	if records.size() != count * 2 or accepted_pin != FileAccess.get_sha256("res://local-art/creatures/accepted-index.json"):
		return
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT))
	assert(report.records.size() == records.size() and report.candidate_sha256 == candidate_pin)
	report.prepared_trial = true
	report.prepared_wrapper_sha256 = FileAccess.get_sha256(get_script().resource_path)
	var output := FileAccess.open(REPORT, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
