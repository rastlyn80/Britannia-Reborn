extends "res://Network/OstardLive.gd"

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const CANDIDATE := "res://../work/creatures/swamp_widow_juka_actions/prepared-client.json"
const REGISTRY_INDEX := "res://local-art/creatures/accepted-index.json"
const REPORT := "res://../outputs/ostard-riding/source-mounts-live.json"

func run() -> void:
	var candidate_pin := FileAccess.get_sha256(CANDIDATE)
	var registry_pin := FileAccess.get_sha256(REGISTRY_INDEX)
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATE))
	var scenes := {}
	for row: Dictionary in rows:
		var body := int(row.bodies[0].body)
		if body not in [794, 799]:
			continue
		assert(row.family == "swamp_widow_juka_actions" and row.status == "prepared")
		assert(row.kind == Registry.entry(body).kind and row.mount_item == Registry.entry(body).mount_item)
		assert(FileAccess.get_sha256(row.assets.modern) == row.authored_action_scene_sha256.modern)
		scenes[str(body)] = row.authored_action_scene_sha256.modern
		Registry.entries[body] = row
	assert(scenes.size() == 2)
	await super.run()
	if records.size() != 10:
		quit(1)
		return
	assert(FileAccess.get_sha256(CANDIDATE) == candidate_pin and FileAccess.get_sha256(REGISTRY_INDEX) == registry_pin)
	var evidence: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT))
	assert(evidence.failures == 0 and evidence.records.size() == records.size())
	evidence.candidate_sha256 = candidate_pin
	evidence.scene_sha256 = scenes
	evidence.check_sha256 = FileAccess.get_sha256(get_script().resource_path)
	evidence.mount_fixture_sha256 = FileAccess.get_sha256("res://../Server/HorseIntegrationFixtures/EquineFixtures.cs")
	evidence.mount_test_sha256 = FileAccess.get_sha256("res://Network/OstardLive.gd")
	var folder := "res://../outputs/creatures/swamp_widow_juka_actions"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var file := FileAccess.open(folder + "/mounted.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(evidence, "\t"))
	file.close()
