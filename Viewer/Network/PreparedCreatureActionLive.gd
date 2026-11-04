extends "res://Network/CreatureLive.gd"
## Run an owned fixture recipe without replacing the active registry on disk.

const INPUT := "res://../work/creatures/live-candidates.json"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--family="):
			family = arg.trim_prefix("--family=")
	assert(family.is_valid_identifier())
	create_timer(150.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string(INPUT))
	assert(not candidates.is_empty())
	for candidate: Dictionary in candidates:
		var body := int(candidate.body)
		var row: Dictionary = candidate.presentation
		assert(row.status == "prepared" and row.family == family and row.kind == Registry.entry(body).kind)
		assert(row.bodies.size() == 1 and int(row.bodies[0].body) == body)
		var reference: Dictionary = row.authored_action_reference
		assert(int(reference.body) == body and row.classic_action_categories.has(str(int(reference.group))))
		for treatment in ["original", "rounded", "modern"]:
			var path: String = row.assets[treatment]
			assert(path.begins_with("res://local-art/creatures/") and path.ends_with(".scn") and not ".." in path)
			assert(FileAccess.get_sha256(path) == row.authored_action_scene_sha256[treatment])
		Registry.entries[body] = row

	await super.run()
	if records.size() != candidates.size() * 2 or accepted_pin != FileAccess.get_sha256("res://local-art/creatures/accepted-index.json"):
		return
	var path := "res://../outputs/creatures/%s/live.json" % family
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(report.records.size() == records.size() and report.candidate_sha256 == candidate_pin)
	report.prepared_trial = true
	report.prepared_wrapper_sha256 = FileAccess.get_sha256(get_script().resource_path)
	var output := FileAccess.open(path, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
