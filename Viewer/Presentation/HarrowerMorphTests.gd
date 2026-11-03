extends SceneTree

const Registry = preload("res://Presentation/CreatureRegistry.gd")
const Avatar = preload("res://Presentation/HumanAvatar.gd")
const Game = preload("res://Network/GameSession.gd")
const Wire = preload("res://Network/LoginProtocol.gd")
const Corpses = preload("res://Presentation/CorpseModels.gd")
const PREPARATION := "res://local-art/creatures/harrower/preparation.json"
const SERIAL := 0x1234

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func update(body: int, hue: int) -> PackedByteArray:
	var packet := PackedByteArray([0x77])
	packet.append_array(Wire.uint_be(SERIAL, 4))
	packet.append_array(Wire.uint_be(body, 2))
	packet.append_array(PackedByteArray([0x05, 0xf3, 0x06, 0xb9, 20, 2]))
	packet.append_array(Wire.uint_be(hue, 2))
	packet.append_array(PackedByteArray([0, 1]))
	return packet

func run() -> void:
	Registry.load_index()
	var preparation: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PREPARATION))
	if "--prepared" in OS.get_cmdline_user_args():
		Registry.entries[146] = preparation.models[0]
	else:
		var expected: Dictionary = preparation.models[0].duplicate()
		expected.status = "validated"
		assert(Registry.entry(146) == expected)
	assert(Registry.supports_body(780))
	var avatar := Avatar.new()
	avatar.initial_body = 146
	root.add_child(avatar)
	avatar.set_physics_process(false)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entity_changed.connect(func(serial: int, entity: Dictionary):
		if serial == SERIAL:
			avatar.apply_server_appearance(entity, []))
	game._handle(update(146, 0))
	var first: Node3D = avatar.horse_visual
	assert(first.native_body == 146 and first.kind == "shadowlords_shadowlord")
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(SERIAL, 4))
	packet.append_array(PackedByteArray([0, 4, 0, 5, 0, 1, 1, 0, 0]))
	game._handle(packet)
	assert(avatar.receive_native_action(game.last_mobile_actions[SERIAL]))
	assert(first.current_clip == "Attack")
	await process_frame
	game._handle(update(780, 0x497))
	assert(not is_instance_valid(first))
	assert(game.entities.size() == 1 and game.entities[SERIAL].body == 780)
	var second: Node3D = avatar.horse_visual
	assert(second.native_body == 780 and second.native_hue == 0x497 and second.kind == "bog_thing")
	assert(avatar.transform.is_equal_approx(Transform3D.IDENTITY))
	game._handle(packet)
	assert(avatar.receive_native_action(game.last_mobile_actions[SERIAL]))
	assert(second.current_clip == "Attack")
	assert(game.world_items.is_empty())
	var corpse := Corpses.build(780, 0x497)
	assert(corpse != null and corpse.get_meta("static_cadaver"))
	assert(corpse.get_meta("corpse_body") == 780 and corpse.get_meta("native_hue") == 0x497)
	assert(corpse.find_children("*", "AnimationPlayer", true, false).is_empty())
	corpse.free()
	await process_frame
	avatar.queue_free()
	game.queue_free()
	await process_frame
	print("shadowlords_shadowlord passed decoded same-serial 146 to 780, both action routes, true-form static corpse")
	quit()
