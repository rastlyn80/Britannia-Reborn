# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-frost-through-gargoyle-actions.gd"

func run() -> void:
	Registry.load_index()
	var index := "res://local-art/creatures/accepted-index.json"
	var digest := FileAccess.get_sha256(index)
	var args := OS.get_cmdline_user_args()
	var active := "--active" in args
	var fire_only := "--fire" in args
	var bodies := [169] if fire_only else [187, 276, 308, 188, 103, 104]
	var rows: Array = []
	if active:
		for body: int in bodies:
			var row := Registry.entry(body)
			assert(row.has("fire_beetle_rest_native_sha256") if fire_only
				else row.get("classic_gesture_batch") == "ridgeback_through_dragons_actions")
			rows.append(row)
	elif fire_only:
		rows = [JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/fire_beetle_rest/preview.json"))]
	else:
		rows = JSON.parse_string(FileAccess.get_file_as_string(
			"res://../work/creatures/ridgeback_through_dragons_actions/prepared-client.json"))
	assert(rows.size() == bodies.size())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var expected := 0
	var expected_poses := 0
	for row: Dictionary in rows:
		var body := int(row.bodies[0].body)
		Registry.entries[body] = row
		game.entities[body] = {"serial": body, "body": body, "hue": 53}
		for treatment: String in row.assets:
			verify_routes(game, body, treatment)
			if body in [169, 187, 188, 276]:
				verify_rest(game, body, treatment)
			if body == 104:
				verify_air_hold(game, treatment)
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
	assert(classic == expected and ground_poses == expected_poses and static_corpses == bodies.size() * 3)
	assert(FileAccess.get_sha256(index) == digest)
	print("RIDGEBACK THROUGH DRAGONS: ", classic, " Classic and ", newer, " newer selections, ",
		ground_poses, " grounded samples and ", static_corpses, " corpse hues, minimum gap ", lowest)
	quit()

func verify_rest(game: Node, body: int, treatment: String) -> void:
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 53)
	actor.set_process(false)
	actor.set_physics_process(false)
	assert(actor.receive_action(decode(game, body, 11)))
	assert(actor.current_clip == "LieDown" and not actor.dead and actor.contact.enabled)
	var rest: Animation = actor.animator.get_animation("LieDown")
	assert(rest.length > 0.0 and (body == 276 or is_equal_approx(rest.length, 0.98)))
	actor._process(actor.action_remaining + 0.1)
	assert(actor.current_clip == "LieDown" and not actor.animator.is_playing())
	actor.play_gait(true, 2.0)
	assert(actor.current_clip == "Walk" and actor.animator.is_playing())
	actor.free()
func verify_air_hold(game: Node, treatment: String) -> void:
	var actor := Registry.create(104)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(104, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	assert(actor.receive_action(decode(game, 104, 21)))
	assert(actor.current_clip == "AirDeath" and actor.dead and not actor.contact.enabled)
	assert(actor.receive_action(decode(game, 104, 2)) and actor.current_clip == "Death" and actor.dead)
	actor.free()