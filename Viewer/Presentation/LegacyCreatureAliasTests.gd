extends SceneTree

const Registry = preload("res://Presentation/CreatureRegistry.gd")
const Game = preload("res://Network/GameSession.gd")
const Wire = preload("res://Network/LoginProtocol.gd")

func _initialize() -> void:
	create_timer(50.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var file := "res://../work/creatures/legacy-aliases/"
	var flags := OS.get_cmdline_user_args()
	var exact := "--exact-fidgets" in flags
	if exact:
		file = "res://../work/creatures/exact_creature_fidgets/accepted-native/candidates.json"
	elif "--late-packages" in flags:
		file += "late-packages.json"
	elif "--preview-packages" in flags:
		file += "packages.json"
	else:
		file += "dread-spider.json" if "--dread-spider" in flags else "candidates.json"
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(file))
	var active := "--active" in OS.get_cmdline_user_args()
	Registry.load_index()
	for row: Dictionary in rows:
		var proof: Dictionary = row.proof if not exact else row.presentation.authored_action_reference.merged({
			"kind": row.presentation.kind, "original_slot": 11, "identical_slot": 17, "clip": "Fidget"})
		var body := int(proof.body)
		if active:
			if exact:
				var record := Registry.entry(body)
				assert(record.legacy_slot11_evidence == row.presentation.legacy_slot11_evidence)
				assert(record.kind == proof.kind)
				if body == 157 and record.get("classic_gesture_batch") == "swamp_widow_juka_actions":
					for treatment: String in row.presentation.asset_sha256:
						assert(FileAccess.get_sha256(record.classic_gesture_base_assets[treatment]) == row.presentation.asset_sha256[treatment])
				else:
					assert(record.asset_sha256 == row.presentation.asset_sha256)
			else:
				assert(Registry.entry(body) == row.presentation, str(proof.kind))
		else:
			Registry.entries[body] = row.presentation
			if proof.has("unchanged_body"):
				Registry.entries[int(proof.unchanged_body)] = row.presentation
		var avatar := preload("res://Presentation/HumanAvatar.gd").new()
		avatar.initial_body = body
		root.add_child(avatar)
		avatar.set_physics_process(false)
		var actor: Node3D = avatar.horse_visual
		assert(actor != null and actor.native_body == body)
		const SERIAL := 0x4100
		game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0}
		for slot: int in [int(proof.identical_slot), int(proof.original_slot)]:
			var packet := PackedByteArray([0x6e])
			packet.append_array(Wire.uint_be(SERIAL, 4))
			packet.append_array(PackedByteArray([0, slot, 0, 5, 0, 1, 1, 0, 0]))
			game._handle(packet)
			assert(avatar.receive_native_action(game.last_mobile_actions[SERIAL]), str(proof.kind))
			assert(actor.current_clip == proof.clip, "%s slot %d" % [proof.kind, slot])
		if proof.has("unchanged_body"):
			var sibling := int(proof.unchanged_body)
			var scale: Vector3 = actor.model.scale
			var original_actor := actor.get_instance_id()
			avatar.apply_server_appearance({"body": sibling, "hue": 0}, [])
			if row.has("unchanged_presentation"):
				assert(avatar.horse_visual.get_instance_id() != original_actor and Registry.entry(sibling) == row.unchanged_presentation)
			else:
				assert(avatar.horse_visual == actor)
			assert(avatar.horse_visual.native_body == sibling and avatar.horse_visual.model.scale.is_equal_approx(scale))
			var unchanged: Dictionary = game.last_mobile_actions[SERIAL].duplicate(true)
			unchanged.body = sibling
			assert(not avatar.receive_native_action(unchanged), "Sibling body has no new slot 11 alias")
			avatar.apply_server_appearance({"body": body, "hue": 0}, [])
			if not row.has("unchanged_presentation"):
				assert(avatar.horse_visual == actor)
			assert(avatar.horse_visual.native_body == body and avatar.receive_native_action(game.last_mobile_actions[SERIAL]))
		avatar.free()
	game.free()
	print("LEGACY CREATURE ALIASES: ", rows.size() * 2, " decoded routes")
	quit()
