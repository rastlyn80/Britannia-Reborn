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
	var file := "res://../work/creatures/legacy-aliases/candidates.json"
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(file))
	var active := "--active" in OS.get_cmdline_user_args()
	Registry.load_index()
	for row: Dictionary in rows:
		var proof: Dictionary = row.proof
		var body := int(proof.body)
		if active:
			assert(Registry.entry(body) == row.presentation, str(proof.kind))
		else:
			Registry.entries[body] = row.presentation
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
		avatar.free()
	game.free()
	print("LEGACY CREATURE ALIASES: ", rows.size() * 2, " decoded routes")
	quit()
