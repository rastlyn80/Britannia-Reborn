extends SceneTree

const Registry = preload("res://Presentation/CreatureRegistry.gd")
const Avatar = preload("res://Presentation/HumanAvatar.gd")
const Game = preload("res://Network/GameSession.gd")
const Wire = preload("res://Network/LoginProtocol.gd")
const Corpses = preload("res://Presentation/CorpseModels.gd")
const PACKAGE := "res://local-art/creatures/champions/preparation.json"
const MONSTER := {4:"Attack", 10:"Hit", 17:"Fidget", 2:"Death"}

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	Registry.load_index()
	var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE))
	for record: Dictionary in package.models:
		var family := str(record.kind)
		var body := int(record.bodies[0].body)
		var expected_record := preload("res://Presentation/LegacyCreatureAliasEvidence.gd").expected_package(record, Registry.entry(body))
		assert(Registry.supports_body(body) and Registry.entry(body) == expected_record)
		var avatar := Avatar.new()
		avatar.initial_body = body
		root.add_child(avatar)
		avatar.set_physics_process(false)
		var actor: Node3D = avatar.horse_visual
		assert(actor != null and avatar.human_visual == null)
		actor.set_process(false)
		actor.set_physics_process(false)
		var serial := 0x1234
		var entity := {"serial": serial, "body": body, "hue": 0}
		var game := Game.new()
		root.add_child(game)
		game.set_process(false)
		game.entities[serial] = entity
		var actions := MONSTER.duplicate()
		if body == 172:
			actions.erase(2)
			actions.merge({5: "Attack2", 19: "Fly", 20: "Land", 2: "Death"})
		else:
			actions[5] = "Attack2"
			actions[6] = "Attack3"
			actions.erase(2)
			actions[2] = "Death"
		for group: int in actions:
			var packet := PackedByteArray([0x6e])
			packet.append_array(Wire.uint_be(serial, 4))
			packet.append_array(PackedByteArray([0, group, 0, 5, 0, 1, 1, 0, 0]))
			game._handle(packet)
			assert(avatar.receive_native_action(game.last_mobile_actions[serial]), family + " group " + str(group))
			var expected: String = actions[group]
			if not actor.animator.has_animation(expected) and expected in ["Attack2", "Attack3"]:
				expected = "Attack"
			assert(actor.current_clip == expected)
		for hue in [0, 53, 0x8035]:
			entity.hue = hue
			avatar.apply_server_appearance(entity, [])
			assert(actor.native_body == body and actor.native_hue == hue)
			var cadaver := Corpses.build(body, hue)
			assert(cadaver != null and cadaver.get_meta("static_cadaver"))
			assert(cadaver.get_meta("corpse_body") == body and cadaver.get_meta("native_hue") == hue)
			assert(cadaver.find_children("*", "AnimationPlayer", true, false).is_empty())
			assert(not cadaver.find_children("*", "MeshInstance3D", true, false).is_empty())
			cadaver.free()
		avatar.free()
		game.free()
		print(family, " passed ", actions.size(), " decoded action routes and three static corpse hues")
	quit()
