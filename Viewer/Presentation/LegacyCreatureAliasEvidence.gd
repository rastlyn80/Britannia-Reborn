extends RefCounted
## Validate the only supplemental field pair permitted on an active package.
static func expected_package(record: Dictionary, active: Dictionary) -> Dictionary:
	var expected := record.duplicate(true)
	expected.status = "validated"
	if active.has("legacy_slot11_evidence"):
		var aliases: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://Presentation/legacy-late-action-aliases.json"))
		var proof: Dictionary = aliases.get(str(int(record.bodies[0].body)), {})
		assert(not proof.is_empty() and proof == active.legacy_slot11_evidence
			and proof.family == record.family and proof.kind == record.kind)
		expected["legacy_slot11_evidence"] = proof
		expected["classic_action_categories"] = record.get("classic_action_categories", {}).merged({"11": "Fidget"}, true)
	return expected
