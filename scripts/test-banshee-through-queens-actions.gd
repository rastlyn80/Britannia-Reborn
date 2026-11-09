# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-frost-through-gargoyle-actions.gd"

const RANKED_BATCH := "banshee_through_queens_actions"
const RANKED_BODIES := [310, 280, 767, 43, 279, 768, 307, 807, 783, 249]
const Retained := preload("res://Presentation/SealedCreatureActionBase.gd")

var ferret_base: Dictionary

func run() -> void:
	Registry.load_index()
	ferret_base = Registry.entry(279)
	var index := "res://local-art/creatures/accepted-index.json"
	var digest := FileAccess.get_sha256(index)
	var active := "--active" in OS.get_cmdline_user_args()
	var rows: Array = []
	if active:
		for body: int in RANKED_BODIES:
			var row := Registry.entry(body)
			assert(row.get("classic_gesture_batch") == RANKED_BATCH)
			rows.append(row)
		ferret_base = Retained.retained(Registry.entry(279), 279)
	else:
		var path := "res://../work/creatures/" + RANKED_BATCH + "/prepared-client.json"
		rows = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(rows.size() == RANKED_BODIES.size())
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
			if body == 43:
				verify_air_hold(game, treatment)
			expected += row.classic_motion_references.size()
			expected_poses += row.archive_grounded_gestures.size() * 31 * SLOPES.size()
		for hue: int in [0, 53, 0x8035]:
			var cadaver := Corpses.build(body, hue)
			assert(cadaver.get_meta("corpse_body") == body and cadaver.get_meta("native_hue") == hue)
			assert(cadaver.get_meta("static_cadaver") and cadaver.get_meta("death_clip") == "Death" and cadaver.find_children("*", "Skeleton3D", true, false).is_empty())
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
	assert(classic == expected and ground_poses == expected_poses and static_corpses == 30)
	assert(FileAccess.get_sha256(index) == digest)
	print("BANSHEE THROUGH QUEENS: ", classic, " Classic and ", newer, " newer selections, ",
		ground_poses, " grounded samples and ", static_corpses, " corpse hues, minimum gap ", lowest)
	quit()

func verify_routes(session: Node, body: int, treatment: String) -> void:
	if body != 279:
		super.verify_routes(session, body, treatment)
		return
	var row := Registry.entry(body)
	var saved := (load(row.assets[treatment]) as PackedScene).instantiate()
	var source := saved.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	Earlier.check_earlier_keys(source, row.classic_gesture_base_assets[treatment])
	saved.free()
	Registry.entries[body] = ferret_base
	var previous := Registry.create(body)
	previous.treatment = treatment
	root.add_child(previous)
	Registry.entries[body] = row
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	var earlier: Animation = previous.animator.get_animation("LieDown")
	var retained: Animation = actor.animator.get_animation("LieDown")
	assert(earlier.length == retained.length and earlier.get_track_count() == retained.get_track_count())
	for track: int in earlier.get_track_count():
		assert(earlier.track_get_path(track) == retained.track_get_path(track))
		assert(earlier.get("tracks/%d/keys" % track) == retained.get("tracks/%d/keys" % track))
	previous.free()
	for slot: String in row.classic_motion_references:
		actor.dead = false
		actor.animator.stop()
		var packet := decode(session, body, int(slot))
		assert(actor.receive_action(packet) and actor.current_clip == row.classic_action_categories[slot])
		assert(actor.get_meta("native_action") == packet)
		classic += 1
	actor.free()
func verify_air_hold(game: Node, treatment: String) -> void:
	var actor := Registry.create(43)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(43, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	assert(actor.receive_action(decode(game, 43, 21)))
	assert(actor.current_clip == "AirDeath" and actor.dead and not actor.contact.enabled)
	assert(actor.animator.get_animation("AirDeath").length < actor.animator.get_animation("Death").length)
	assert(actor.receive_action(decode(game, 43, 2)) and actor.current_clip == "Death" and actor.dead)
	actor.free()