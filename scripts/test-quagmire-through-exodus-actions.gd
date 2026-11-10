# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-frost-through-gargoyle-actions.gd"

const QUAGMIRE_FAMILY := "quagmire_through_exodus_actions"
const QUAGMIRE_BODIES := [789, 784, 266, 772, 267, 304, 46, 757, 756, 252, 199, 271]

func run() -> void:
	Registry.load_index()
	var index := "res://local-art/creatures/accepted-index.json"
	var digest := FileAccess.get_sha256(index)
	var active := "--active" in OS.get_cmdline_user_args()
	var rows: Array = []
	if active:
		for body: int in QUAGMIRE_BODIES:
			var row := Registry.entry(body)
			assert(row.get("classic_gesture_batch") == QUAGMIRE_FAMILY)
			rows.append(row)
	else:
		var path := "res://../work/creatures/" + QUAGMIRE_FAMILY + "/prepared-client.json"
		rows = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(rows.size() == QUAGMIRE_BODIES.size())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var expected := 0
	var expected_newer := 9
	var expected_poses := 0
	for row: Dictionary in rows:
		var body := int(row.bodies[0].body)
		if body == 267 and row.has("troglodyte_enhanced"):
			expected_newer += 2 * row.assets.size()
		Registry.entries[body] = row
		game.entities[body] = {"serial": body, "body": body, "hue": 53}
		for treatment: String in row.assets:
			verify_routes(game, body, treatment)
			expected += row.classic_motion_references.size()
			expected_poses += row.archive_grounded_gestures.size() * 31 * SLOPES.size()
		for hue: int in [0, 53, 0x8035]:
			var cadaver := Corpses.build(body, hue)
			assert(cadaver.get_meta("corpse_body") == body and cadaver.get_meta("native_hue") == hue)
			assert(cadaver.get_meta("static_cadaver") and cadaver.find_children("*", "Skeleton3D", true, false).is_empty())
			cadaver.free()
			static_corpses += 1
	game.free()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for row: Dictionary in rows:
			for treatment: String in row.assets:
				sample_ranked_ground(plane, int(row.bodies[0].body), treatment)
		plane.free()
		await physics_frame
	assert(classic == expected and ground_poses == expected_poses and static_corpses == 36 and newer == expected_newer and lowest > 0.0004)
	assert(FileAccess.get_sha256(index) == digest)
	print("QUAGMIRE THROUGH EXODUS: ", classic, " Classic and ", newer, " newer selections, ",
		ground_poses, " grounded samples and ", static_corpses, " corpse hues, minimum gap ", lowest)
	quit()
