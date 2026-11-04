extends "res://../scripts/test-hopper-horde-actions.gd"

const HumanAvatar := preload("res://Presentation/HumanAvatar.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")
const BODY := 77
const CLIPS := {11: "Fidget", 17: "Fidget", 18: "Fidget2"}

func run() -> void:
	Registry.load_index()
	if not "--active" in OS.get_cmdline_user_args():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/kraken_fidgets/candidates.json"))
		assert(not rows.is_empty())
		for row: Dictionary in rows:
			assert(int(row.body) == BODY and row.presentation == rows[0].presentation)
		Registry.entries[BODY] = rows[0].presentation
	var entry := Registry.entry(BODY)
	assert(entry.movement_mode == "native_waterline")
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	const SERIAL := 0x5678
	game.entities[SERIAL] = {"serial": SERIAL, "body": BODY, "hue": 0x8035}
	var deck := StaticBody3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(35.0, 0.1, 35.0)
	var collider := CollisionShape3D.new()
	collider.shape = box
	deck.add_child(collider)
	root.add_child(deck)
	for treatment: String in ["original", "rounded", "modern"]:
		assert(FileAccess.get_sha256(entry.assets[treatment]) == entry.authored_action_scene_sha256[treatment])
		var trial := entry.duplicate(true)
		trial.assets.modern = entry.assets[treatment]
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
		for height: float in [-4.0, 0.35]:
			deck.position.y = height
			deck.rotation.x = 0.09
			await physics_frame
			await physics_frame
			var first := PackedVector2Array()
			for group: int in CLIPS:
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(SERIAL, 4))
				packet.append_array(PackedByteArray([0, group, 0, 5, 0, 1, 1, 0, 0]))
				game._handle(packet)
				var path := sample_action(avatar, game.last_mobile_actions[SERIAL], CLIPS[group])
				if group == 11:
					first = path
				elif group == 17:
					assert(first == path)
				else:
					var shallow := lift(first)
					var sweep := lift(path)
					assert(shallow > 0.08 and shallow < 0.9 and sweep > 2.0)
					print(treatment, " support ", height, " shallow/sweep lift ", [shallow, sweep])
		avatar.free()
	Registry.entries[BODY] = entry
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(BODY, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver") and int(corpse.get_meta("native_hue")) == hue)
		assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
	deck.free()
	game.free()
	print("KRAKEN: 18 decoded fidgets over seabed/deck, exact source sweep keys, three corpse hues")
	quit()

func original_tracks(player: AnimationPlayer, treatment: String) -> bool:
	var model := (load("res://local-art/creatures/krakens_kraken-%s.gltf" % treatment) as PackedScene).instantiate()
	var source := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for label in source.get_animation_list():
		var before := source.get_animation(label)
		var after := player.get_animation("Fidget2" if label == "Fidget" else label)
		assert(after != null and before.length == after.length and before.get_track_count() == after.get_track_count())
		for track in before.get_track_count():
			assert(before.track_get_path(track) == after.track_get_path(track))
			assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track))
	model.free()
	return true

func sample_action(avatar: Node3D, packet: Dictionary, clip: String) -> PackedVector2Array:
	var actor: Node3D = avatar.horse_visual
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var basis: Basis = actor.model.basis
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.stop()
	actor.play("Idle", 0.0)
	player.advance(0.0)
	assert(avatar.receive_native_action(packet) and actor.current_clip == clip)
	var delta: float = actor.action_remaining / 48.0
	var result := PackedVector2Array()
	for sample in 49:
		player.advance(0.0 if sample == 0 else delta)
		avatar._physics_process(delta)
		actor._physics_process(delta)
		rig.force_update_all_bone_transforms()
		var bounds := Geometry.deformed_bounds(mesh, rig)
		assert(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length() < 22.0)
		assert(avatar.global_position.is_zero_approx() and is_zero_approx(avatar.ground_offset))
		assert(actor.contact.contacts.is_empty() and actor.model.basis.is_equal_approx(basis))
		result.append(Vector2(tip(rig, "l"), tip(rig, "r")))
	actor._process(actor.action_remaining + 0.001)
	avatar.animate(false, 0.0, 0.016, 0.0)
	assert(actor.current_clip == "Idle")
	return result

func tip(rig: Skeleton3D, side: String) -> float:
	var bone := rig.find_bone("bip01 " + side + " toe02")
	assert(bone >= 0)
	return rig.to_global(rig.get_bone_global_pose(bone).origin).y

func lift(path: PackedVector2Array) -> float:
	var highest := 0.0
	for tips in path:
		highest = maxf(highest, maxf(tips.x - path[0].x, tips.y - path[0].y))
	return highest
