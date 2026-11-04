extends "res://../scripts/test-kraken-fidgets.gd"

const REACTIONS := {10: "Hit", 15: "BriefHit", 16: "BriefHit"}

func run() -> void:
	Registry.load_index()
	var row := Registry.entry(BODY)
	if not "--active" in OS.get_cmdline_user_args():
		var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string(
			"res://../work/creatures/kraken_reactions/candidates.json"))
		assert(candidates.size() == 2 and candidates[0].presentation == candidates[1].presentation)
		row = candidates[0].presentation
	else:
		assert(row.classic_gesture_batch == "kraken_reactions")
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	const SERIAL := 0x5678
	game.entities[SERIAL] = {"serial": SERIAL, "body": BODY, "hue": 0x8035}
	var deck := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(35.0, 0.1, 35.0)
	collider.shape = box
	deck.add_child(collider)
	root.add_child(deck)
	deck.rotation.x = 0.09
	for treatment: String in row.assets:
		assert(FileAccess.get_sha256(row.assets[treatment]) == row.authored_action_scene_sha256[treatment])
		var trial := row.duplicate(true)
		trial.assets.modern = row.assets[treatment]
		Registry.entries[BODY] = trial
		var avatar := HumanAvatar.new()
		avatar.initial_body = BODY
		root.add_child(avatar)
		avatar.set_physics_process(false)
		var actor: Node3D = avatar.horse_visual
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.apply_identity(BODY, 0x8035)
		assert(actor.native_hue == 0x8035 and actor.contact.feet.is_empty())
		assert(original_tracks(actor.animator, treatment))
		var brief: Animation = actor.animator.get_animation("BriefHit")
		assert(brief.length < actor.animator.get_animation("Hit").length)
		for track in brief.get_track_count():
			assert(brief.track_get_key_value(track, 0) == brief.track_get_key_value(track, brief.track_get_key_count(track) - 1))
		for height: float in [-4.0, 0.35]:
			deck.position.y = height
			await physics_frame
			await physics_frame
			var paths := {}
			for slot: int in REACTIONS:
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(SERIAL, 4))
				packet.append_array(PackedByteArray([0, slot, 0, 4 if slot == 10 else 3, 0, 1, 1, 0, 0]))
				game._handle(packet)
				paths[slot] = sample_action(avatar, game.last_mobile_actions[SERIAL], REACTIONS[slot])
			assert(paths[15] == paths[16])
			assert(paths[15][48].distance_to(paths[15][24]) > 0.5)
			assert(paths[10][35].distance_to(paths[15][35]) > 0.15)
		avatar.free()
	Registry.entries[BODY] = row
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(BODY, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver") and int(corpse.get_meta("native_hue")) == hue)
		corpse.free()
	deck.free()
	game.free()
	print("KRAKEN RECOILS PASS: 882 decoded poses over seabed and deck, retained source keys, three corpse hues")
	quit()
