extends "res://../scripts/test-frost-through-gargoyle-actions.gd"

const LATTICE_FAMILY := "lattice_through_meer_actions"
const BEETLE_FAMILY := "giant_beetle_rest"
const RetainedBase := preload("res://Presentation/SealedCreatureActionBase.gd")
const LATTICE_BODIES := [123, 785, 189, 241, 770, 301, 277, 773]
const BEETLE := 791
const CAPTAIN := 773
var crossbow_poses := 0

func run() -> void:
	Registry.load_index()
	var args := OS.get_cmdline_user_args()
	var beetle_only := "--beetle" in args
	var active := "--active" in args
	var bodies := [BEETLE] if beetle_only else LATTICE_BODIES
	if not active:
		var value: Variant
		if beetle_only:
			value = [JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/giant_beetle_rest/preview.json"))]
		else:
			value = JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/lattice_through_meer_actions/prepared-client.json"))
		assert(value is Array and value.size() == bodies.size())
		for row: Dictionary in value:
			Registry.entries[int(row.bodies[0].body)] = row
	elif not beetle_only:
		for body: int in [770, 773]:
			var active_row := Registry.entry(body)
			if active_row.get("classic_gesture_batch") == "meer_forward_falls":
				Registry.entries[body] = RetainedBase.retained(active_row, body)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var expected_ground := 0
	var expected_newer := 0
	for body: int in bodies:
		var row := Registry.entry(body)
		if active:
			assert(row.has("beetle_rest_native_sha256") if beetle_only else row.classic_gesture_batch == LATTICE_FAMILY)
		else:
			assert(row.family == (BEETLE_FAMILY if beetle_only else LATTICE_FAMILY))
		game.entities[body] = {"serial": body, "body": body, "hue": 53}
		for treatment: String in row.assets:
			verify_routes(game, body, treatment)
			expected_ground += row.archive_grounded_gestures.size() * 31 * SLOPES.size()
			expected_newer += row.new_action_categories.size()
			if body == BEETLE:
				verify_rest(game, treatment)
			elif body == CAPTAIN:
				verify_crossbow(game, treatment)
		for hue: int in [0, 53, 0x8035]:
			var cadaver := Corpses.build(body, hue)
			assert(cadaver.get_meta("corpse_body") == body and cadaver.get_meta("native_hue") == hue)
			assert(cadaver.get_meta("static_cadaver") and cadaver.find_children("*", "AnimationPlayer", true, false).is_empty())
			cadaver.free()
			static_corpses += 1
	game.free()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for body: int in bodies:
			for treatment: String in Registry.entry(body).assets:
				sample_ranked_ground(plane, body, treatment)
		plane.free()
		await physics_frame
	assert(classic == 39 * bodies.size() and newer == expected_newer)
	assert(static_corpses == 3 * bodies.size() and ground_poses == expected_ground and lowest > 0.0004)
	assert(crossbow_poses == (0 if beetle_only else 315))
	print("LATTICE THROUGH MEER: ", classic, " Classic and ", newer, " newer selections, ", static_corpses,
		" corpse hues, ", ground_poses, " terrain poses, ", crossbow_poses, " crossbow poses, minimum gap ", lowest)
	quit()

func verify_rest(game: Node, treatment: String) -> void:
	var actor := create_fitted_actor(BEETLE, treatment)
	assert(actor.receive_action(decode(game, BEETLE, 11)))
	assert(actor.current_clip == "LieDown" and actor.contact.enabled and not actor.dead)
	actor._process(actor.action_remaining + 0.1)
	assert(actor.current_clip == "LieDown" and not actor.animator.is_playing())
	actor.play_gait(true, 2.0)
	assert(actor.current_clip == "Walk" and actor.animator.is_playing())
	actor.free()

func verify_crossbow(game: Node, treatment: String) -> void:
	var actor := create_fitted_actor(CAPTAIN, treatment)
	actor.set_equipment([{"id": 0x0f50, "layer": 2}])
	assert(actor.crossbow.visible)
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	for slot: int in [5, 6, 8, 15, 18]:
		player.stop()
		assert(actor.receive_action(decode(game, CAPTAIN, slot)))
		player.advance(0.0)
		for sample in 21:
			player.seek(player.current_animation_length * sample / 20.0, true)
			var hand := rig.to_global(rig.get_bone_global_pose(actor.right_grasp).origin)
			assert(actor.crossbow.to_global(actor.GRIP).distance_to(hand) < 0.0001)
			crossbow_poses += 1
	actor.set_equipment([])
	assert(not actor.crossbow.visible)
	actor.free()

func create_fitted_actor(body: int, treatment: String) -> Node3D:
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 53)
	actor.set_process(false)
	actor.set_physics_process(false)
	return actor
