extends RefCounted
## Older route checks can still exercise the exact retained action layer.

static func retained(row: Dictionary, body: int) -> Dictionary:
	var path := "res://../work/creatures/%s/accepted-native/base-rows.json" % row.classic_gesture_batch
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	var matches := rows.filter(func(candidate: Dictionary) -> bool:
		return candidate.bodies.size() == 1 and int(candidate.bodies[0].body) == body)
	assert(matches.size() == 1)
	var base: Dictionary = matches[0]
	var assets: Dictionary = base.get("assets", {})
	if assets.is_empty():
		assets = {}
		for treatment: String in base.asset_sha256:
			assets[treatment] = preload("res://Presentation/CreatureRegistry.gd").asset_path(base, treatment)
	assert(row.classic_gesture_base_assets == assets and row.bodies == base.bodies)
	for treatment: String in assets:
		var digest: String = (base.asset_sha256[treatment] if base.has("asset_sha256")
			else base.saved_scenes[treatment].scene_sha256)
		assert(FileAccess.get_sha256(assets[treatment]) == digest)
	return base
