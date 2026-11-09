extends "res://Presentation/SourcePreservingActionTests.gd"
## Recheck the sealed base material and rig before applying newer action layers.

func run() -> void:
	if Registry.entry(752).get("classic_gesture_batch") == "golem_raptor_juka_solen_actions":
		use_base(752, "golem_raptor_juka_solen_actions")
	for body in [259, 264]:
		if Registry.entry(body).get("classic_gesture_batch") == "ranked_classic_actions":
			use_base(body, "ranked_classic_actions")
	for body in [794, 799]:
		if Registry.entry(body).get("classic_gesture_batch") == "swamp_widow_juka_actions":
			use_base(body, "swamp_widow_juka_actions")
	for body in [182, 777]:
		if Registry.entry(body).get("classic_gesture_batch") == "bomber_ogre_rune_dopple_actions":
			use_base(body, "bomber_ogre_rune_dopple_actions")
	if Registry.entry(259).has("classic_gesture_native_sha256"):
		use_base(259, "grizzle_antler")
	if Registry.entry(143).get("classic_gesture_batch") == "ratman_lava_actions":
		use_base(143, "ratman_lava_actions")
	super.run()

func use_base(body: int, batch: String) -> void:
	var active := Registry.entry(body)
	var path := "res://../work/creatures/%s/accepted-native/base-rows.json" % batch
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	var matches := rows.filter(func(row: Dictionary) -> bool: return row.kind == active.kind)
	assert(matches.size() == 1)
	var base: Dictionary = matches[0]
	assert(base.assets == active.classic_gesture_base_assets and base.bodies == active.bodies)
	if batch == "grizzle_antler":
		assert(base.presentation_script == active.presentation_script)
	Registry.entries[body] = base
