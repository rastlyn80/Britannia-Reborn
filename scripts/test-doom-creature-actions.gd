# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-frost-through-gargoyle-actions.gd"

const DOOM_BATCH := "doom_creature_actions"
const DOOM_BODIES := [306, 311, 312, 313, 314, 315, 316, 318, 319]

func run() -> void:
	Registry.load_index()
	var rows: Array = []
	var index := "res://local-art/creatures/accepted-index.json"
	var digest := FileAccess.get_sha256(index)
	if "--active" in OS.get_cmdline_user_args():
		for body: int in DOOM_BODIES:
			var row := Registry.entry(body)
			assert(row.get("classic_gesture_batch") == DOOM_BATCH)
			rows.append(row)
	else:
		var path := "res://../work/creatures/%s/prepared-client.json" % DOOM_BATCH
		rows = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(rows.size() == DOOM_BODIES.size())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var expected_ground := 0
	for row: Dictionary in rows:
		var body := int(row.bodies[0].body)
		Registry.entries[body] = row
		game.entities[body] = {"serial": body, "body": body, "hue": 53}
		for treatment: String in row.assets:
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			var groups := [15, 16, 18] if body == 306 else [6, 15, 16, 18]
			for group: int in groups:
				assert(actor.receive_action(decode(game, body, group)), str([body, group]))
				assert(actor.current_clip == row.classic_action_categories[str(group)])
				classic += 1
			assert(not actor.dead)
			assert(actor.receive_action(decode(game, body, 2)) and actor.current_clip == "Death")
			actor.free()
			expected_ground += row.archive_grounded_gestures.size() * 31 * SLOPES.size()
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.get_meta("static_cadaver") and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			corpse.free()
			static_corpses += 1
	game.free()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for row: Dictionary in rows:
			for treatment: String in row.assets:
				sample_ranked_ground(plane, int(row.bodies[0].body), treatment)
		plane.free()
		await physics_frame
	assert(classic == 105 and static_corpses == 27 and ground_poses == expected_ground)
	assert(FileAccess.get_sha256(index) == digest)
	print("DOOM CREATURE GESTURES: ", classic, " decoded selections, ", ground_poses, " terrain poses, ",
		static_corpses, " corpse hues, minimum ", lowest)
	quit()
