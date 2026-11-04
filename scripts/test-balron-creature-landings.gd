extends "res://../scripts/test-later-creature-bat-landings.gd"

func run() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var path := "res://../work/creatures/armed_flying_creature_gestures/candidates.json"
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(rows.size() == 4)
		for row: Dictionary in rows:
			if int(row.body) == 40:
				Registry.entries[40] = row.presentation
	for tilt: Vector3 in [Vector3.ZERO, Vector3(0.14, 0.0, 0.11), Vector3(-0.12, 0.0, -0.10)]:
		await witness(40, tilt, 0, 0.0)
		await witness(40, tilt, 21, 0.07)
		await witness(40, tilt, 21, 0.43)
		await witness(40, tilt, -1, 0.0)
	print("BALRON CORPSES: 12 decoded handoffs across 492 terrain samples")
	quit()

func ground_width() -> float:
	return 24.0
