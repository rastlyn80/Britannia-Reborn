extends "res://../scripts/test-golem-raptor-juka-solen-actions.gd"

const RANK_BATCH := "frost_through_gargoyle_actions"
const RANK_BODIES := [20, 792, 771, 265, 281, 130, 755, 754]
const FIRE_BODY := 130
var ground_poses := 0
var lowest := INF
var fire_variants := 0
var fire_gaits := 0

func run() -> void:
	Registry.load_index()
	var index := "res://local-art/creatures/accepted-index.json"
	var digest := FileAccess.get_sha256(index)
	var active := "--active" in OS.get_cmdline_user_args()
	if not active:
		var path := "res://../work/creatures/%s/prepared-client.json" % RANK_BATCH
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(rows.size() == RANK_BODIES.size())
		for row: Dictionary in rows:
			Registry.entries[int(row.bodies[0].body)] = row
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var expected_newer := 0
	var expected_poses := 0
	for body: int in RANK_BODIES:
		var row := Registry.entry(body)
		assert(row.get("classic_gesture_batch" if active else "family") == RANK_BATCH)
		game.entities[body] = {"serial": body, "body": body, "hue": 53}
		for treatment: String in row.assets:
			verify_routes(game, body, treatment)
			expected_newer += row.new_action_categories.size()
			expected_poses += row.archive_grounded_gestures.size() * 31 * SLOPES.size()
			if body == FIRE_BODY:
				verify_fire_modes(game, treatment)
		for hue: int in [0, 53, 0x8035]:
			var cadaver := Corpses.build(body, hue)
			assert(cadaver.get_meta("corpse_body") == body and cadaver.get_meta("native_hue") == hue)
			assert(cadaver.get_meta("static_cadaver") and cadaver.get_meta("death_clip") == "Death")
			assert(cadaver.find_children("*", "AnimationPlayer", true, false).is_empty())
			cadaver.free()
			static_corpses += 1
	game.free()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for body: int in RANK_BODIES:
			for treatment: String in Registry.entry(body).assets:
				sample_ranked_ground(plane, body, treatment)
		for phase: float in [0.08, 0.45, 0.78]:
			witness(plane, FIRE_BODY, 3, phase)
		plane.free()
		await physics_frame
	assert(FileAccess.get_sha256(index) == digest and classic == 357 and newer == expected_newer)
	assert(static_corpses == 24 and fire_variants == 9 and fire_gaits == 18)
	assert(ground_poses == expected_poses and lowest > 0.0004 and handoffs == 9 and checked == 369)
	print("FROST THROUGH GARGOYLE: ", ground_poses, " grounded poses, ", classic, " Classic and ", newer,
		" newer decoded selections, ", static_corpses, " corpse hues, minimum gap ", lowest, " m")
	print("FIRE GARGOYLE: ", fire_variants, " variation selections, ", fire_gaits, " gait selections, ",
		handoffs, " alternate corpse handoffs and ", checked, " fall poses")
	quit()

func verify_fire_modes(game: Node, treatment: String) -> void:
	var actor := Registry.create(FIRE_BODY)
	actor.treatment = treatment
	root.add_child(actor)
	actor.set_process(false)
	actor.set_physics_process(false)
	for variant: Array in [[0, "FireGargoyleLunge"], [3, "Death2"], [5, "FireGargoyleFlare"]]:
		actor.dead = false
		actor.animator.stop()
		assert(actor.receive_action(NewPacket.decode_new(game, FIRE_BODY, variant[0], 0, 1)))
		assert(actor.current_clip == variant[1])
		fire_variants += 1
	actor.dead = false
	actor.action_remaining = 0.0
	for flags: int in [0, 0x40]:
		actor.set_native_combat_flags(flags)
		actor.play_gait(false, 0.0)
		assert(actor.current_clip == ("ReadyStance" if flags == 0 else "Idle"))
		actor.play_gait(true, 2.0)
		assert(actor.current_clip == ("FireGargoylePeaceWalk" if flags == 0 else "Walk"))
		actor.play_gait(true, 7.0)
		assert(actor.current_clip == "Run")
		fire_gaits += 3
	actor.free()

func sample_ranked_ground(plane: StaticBody3D, body: int, treatment: String) -> void:
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 53)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var normal := plane.global_basis.y.normalized()
	var anchor := actor.global_transform
	for clip: String in actor.entry.archive_grounded_gestures:
		player.stop()
		actor.current_clip = clip
		player.play(clip, 0.0)
		player.advance(0.0)
		for frame in 31:
			player.seek(player.current_animation_length * frame / 30.0, true)
			actor._physics_process(1.0 / 60.0)
			actor.contact._process_modification_with_delta(1.0 / 60.0)
			rig.force_update_all_bone_transforms()
			actor.contact.modification_processed.emit()
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
			assert(is_finite(gap) and gap > 0.0004 and actor.global_transform == anchor,
				str([body, treatment, clip, frame, gap]))
			lowest = minf(lowest, gap)
			ground_poses += 1
	actor.free()

func expected_fall(_body: int, _group: int) -> String:
	return "Death2"
