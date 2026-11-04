extends "res://Presentation/SourcePreservingActionTests.gd"
## Recheck the base material and skin receipt independently of the antler action.

func run() -> void:
	var active := Registry.entry(259)
	if active.has("classic_gesture_native_sha256"):
		var path := "res://../work/creatures/grizzle_antler/accepted-native/base-rows.json"
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(rows.size() == 1)
		var base: Dictionary = rows[0]
		assert(base.kind == active.kind and base.assets == active.classic_gesture_base_assets)
		assert(base.bodies == active.bodies and base.presentation_script == active.presentation_script)
		Registry.entries[259] = base
	super.run()
