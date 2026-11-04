extends "res://Network/CreatureLive.gd"
## Reuse the pinned native harness with process-local weapon routes.

const INPUT := "res://../work/creatures/live-candidates.json"
const REPORT := "res://../outputs/creatures/lizard_armed/live.json"

func _initialize() -> void:
	family = "lizard_armed"
	create_timer(120.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string(INPUT))
	var forms := {35: "spear", 36: "mace"}
	assert(candidates.size() == forms.size())
	Registry.load_index()
	for candidate: Dictionary in candidates:
		var body := int(candidate.body)
		assert(forms.has(body) and candidate.native_class == "Lizardman")
		var form: String = forms[body]
		forms.erase(body)
		var record: Dictionary = candidate.presentation
		assert(record.status == "prepared" and record.kind == "lizardman_" + form)
		assert(record.presentation_script == "res://Presentation/SourceArmedLizardmanVisual.gd")
		assert(FileAccess.get_sha256(record.presentation_script) == record.presentation_script_sha256)
		var path: String = record.assets.modern
		assert(path == "res://local-art/creatures/lizardman-pillage-trial-%s.scn" % form)
		assert(FileAccess.get_sha256(path) == record.asset_sha256.modern)
		Registry.entries[body] = record

	# The base harness records the exact native witness and schedules quit.
	# Record the process-local routing before the tree exits.
	await super.run()
	if records.size() != candidates.size() * 2:
		return
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT))
	assert(report.records.size() == records.size() and report.candidate_sha256 == candidate_pin)
	report.prepared_trial = true
	report.prepared_wrapper_sha256 = FileAccess.get_sha256(get_script().resource_path)
	var output := FileAccess.open(REPORT, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
