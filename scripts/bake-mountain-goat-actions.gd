extends "res://../scripts/bake-grazers-grizzly-actions.gd"

func run() -> void:
	active_body = 209
	var variants := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(Registry.entry(88), treatment)
		assert(FileAccess.get_sha256(source) == Registry.entry(88).asset_sha256[treatment])
		var target := "res://local-art/creatures/mountain-goat-actions-%s.scn" % treatment
		bake(88, source, target)
		variants[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(target)}
	save_receipt("res://local-art/creatures/mountain-goat-actions-bake.json", {"88": variants})
	quit()
