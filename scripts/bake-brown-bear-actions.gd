extends "res://../scripts/bake-dog-bear-actions.gd"

func run() -> void:
	const BODY := 167
	var row := Registry.entry(BODY)
	assert(not row.has("classic_gesture_batch"))
	var scenes := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(row, treatment)
		var digest := FileAccess.get_sha256(source)
		assert(digest == row.asset_sha256[treatment])
		var output := "res://local-art/creatures/field-fauna-%d-%s.scn" % [BODY, treatment]
		bake(BODY, source, output)
		scenes[treatment] = {"source": digest, "scene": FileAccess.get_sha256(output)}
	var receipt := FileAccess.open("res://local-art/creatures/brown-bear-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	var inputs := {}
	for path: String in [get_script().resource_path, "res://../scripts/bake-dog-bear-actions.gd",
			"res://../scripts/bake-quadruped-actions.gd", "res://Presentation/WaterElementalFidgets.gd",
			"res://Presentation/SourceGroundLookup.gd"]:
		inputs[path.get_file()] = FileAccess.get_sha256(path)
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": scenes}))
	receipt.close()
	quit()
