extends "res://../scripts/bake-grazers-grizzly-actions.gd"

func run() -> void:
	var scenes := {}
	var pig := Registry.entry(203)
	# The Pig and Boar share the same named leg chains. Refit the Boar
	# controls on the Pig's own rig, stance, dimensions and recovered attack.
	active_body = 290
	for treatment: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(pig, treatment)
		var target := "res://local-art/creatures/pig-actions-%s.scn" % treatment
		bake(203, source, target)
		scenes[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(target)}
	var inputs := {}
	for file: String in [get_script().resource_path, "res://../scripts/bake-grazers-grizzly-actions.gd",
		"res://../scripts/bake-dog-bear-actions.gd",
		"res://../scripts/bake-quadruped-actions.gd",
		"res://Presentation/WaterElementalFidgets.gd",
		"res://Presentation/SourceGroundLookup.gd"]:
		inputs[file.get_file()] = FileAccess.get_sha256(file)
	var receipt := FileAccess.open("res://local-art/creatures/pig-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": scenes}))
	receipt.close()
	quit()
