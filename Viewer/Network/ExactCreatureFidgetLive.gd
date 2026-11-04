extends "res://Network/CreatureLive.gd"
## Verify packet routing with the original accepted scenes and their materials.

func _initialize() -> void:
	family = "exact_creature_fidgets"
	create_timer(150.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/live-candidates.json"))
	assert(candidates.size() == 4)
	for candidate: Dictionary in candidates:
		var body := int(candidate.body)
		assert(body in [146, 157, 173, 777])
		var base := Registry.entry(body)
		var row: Dictionary = candidate.presentation
		assert(row.family == family and row.status == "prepared" and row.bodies == base.bodies)
		assert(row.classic_action_categories["11"] == "Fidget" and int(row.authored_action_reference.body) == body)
		for treatment in ["original", "rounded", "modern"]:
			var path := Registry.asset_path(row, treatment)
			assert(path == Registry.asset_path(base, treatment))
			assert(FileAccess.get_sha256(path) == base.asset_sha256[treatment])
		var trial := base.duplicate(true)
		trial.classic_action_categories = row.classic_action_categories
		Registry.entries[body] = trial
	await super.run()
	if records.size() != candidates.size() * 2:
		return
	var path := "res://../outputs/creatures/exact_creature_fidgets/live.json"
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(report.candidate_sha256 == candidate_pin)
	report.prepared_trial = true
	report.prepared_wrapper_sha256 = FileAccess.get_sha256(get_script().resource_path)
	var output := FileAccess.open(path, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
