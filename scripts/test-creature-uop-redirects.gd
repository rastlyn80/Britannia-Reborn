extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const SealedBase := preload("res://Presentation/SealedCreatureActionBase.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const SERIAL := 0x4100
const PREVIEW := "res://../work/creatures/uop_redirects/preview.json"

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	assert(not rows.is_empty())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var destinations := 0
	var redirects := 0
	var active := "--active" in OS.get_cmdline_user_args()
	for candidate: Dictionary in rows:
		var body := int(candidate.body)
		var registered := Registry.entry(body)
		var original: Dictionary = candidate.baseline if active else registered
		assert(original.kind == candidate.kind)
		if active:
			assert(registered == candidate.presentation)
		var redirect_layer: Dictionary = candidate.presentation
		if active and registered.get("classic_gesture_batch") == "golem_raptor_juka_solen_actions":
			redirect_layer = SealedBase.retained(registered, body)
		game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0x8035}
		for treatment in ["original", "rounded", "modern"]:
			Registry.entries[body] = original
			var baseline := create_actor(body, treatment)
			Registry.entries[body] = registered if active else candidate.presentation
			var actor := create_actor(body, treatment)
			assert(actor.native_hue == baseline.native_hue and actor.native_hue == 0x8035)
			var assets: Dictionary = redirect_layer.get("classic_gesture_base_assets", {})
			var candidate_path := Registry.asset_path(redirect_layer, treatment)
			if active and body in [730, 734] and not assets.is_empty():
				candidate_path = assets[treatment]
			# The Slith successor retains the ready-stance scene as its immediate
			# base. Its redirect destinations must still match the original keys below.
			if redirect_layer.get("classic_gesture_batch") != "slith_actions":
				assert(Registry.asset_path(original, treatment) == candidate_path)
			for group: String in candidate.targets:
				var target: Dictionary = candidate.targets[group]
				assert(baseline.receive_action(decode(game, int(group))) and baseline.current_clip == target.clip)
				var original_clip: Animation = baseline.animator.get_animation(target.clip)
				var redirected_clip: Animation = actor.animator.get_animation(target.clip)
				assert(original_clip.length == redirected_clip.length
					and original_clip.get_track_count() == redirected_clip.get_track_count())
				for track in original_clip.get_track_count():
					assert(original_clip.track_get_path(track) == redirected_clip.track_get_path(track))
					assert(original_clip.get("tracks/%d/keys" % track) == redirected_clip.get("tracks/%d/keys" % track))
				destinations += 1
				for slot: int in candidate.targets[group].slots:
					var packet := decode(game, slot)
					assert(not baseline.receive_action(packet), "An already supported action would be overwritten")
					assert(actor.receive_action(packet) and actor.current_clip == target.clip,
						"Body %d slot %d must play %s" % [body, slot, target.clip])
					assert(actor.contact.enabled == baseline.contact.enabled and not actor.dead)
					redirects += 1
			baseline.queue_free()
			actor.queue_free()
			await process_frame
		Registry.entries[body] = registered
	game.free()
	print("UOP REDIRECTS: ", redirects, " redirected decoded routes and ", destinations,
		" destination checks across ", rows.size(), " bodies")
	quit()

func create_actor(body: int, treatment: String) -> Node3D:
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.apply_identity(body, 0x8035)
	return actor

func decode(game: Node, slot: int) -> Dictionary:
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(SERIAL, 4))
	packet.append_array(PackedByteArray([0, slot, 0, 5, 0, 1, 1, 0, 0]))
	game._handle(packet)
	return game.last_mobile_actions[SERIAL]
