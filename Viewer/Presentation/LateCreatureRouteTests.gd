extends SceneTree

const Registry = preload("res://Presentation/CreatureRegistry.gd")
const Avatar = preload("res://Presentation/HumanAvatar.gd")
const Game = preload("res://Network/GameSession.gd")
const Wire = preload("res://Network/LoginProtocol.gd")
const Corpses = preload("res://Presentation/CorpseModels.gd")
const MONSTER := {4:"Attack", 5:"Attack2", 6:"Attack3", 10:"Hit", 17:"Fidget", 2:"Death"}
const ANIMAL := {3:"Eat", 4:"Alert", 5:"Attack", 6:"Attack2", 7:"Hit", 11:"LieDown", 8:"Death"}

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	Registry.load_index()
	var package_family := "hydra" if "--family=hydra" in OS.get_cmdline_user_args() else "late_source"
	if "--family=aos_creatures" in OS.get_cmdline_user_args():
		package_family = "aos_creatures"
	if "--family=aos_aliases" in OS.get_cmdline_user_args():
		package_family = "aos_aliases"
	if "--family=aos_mound" in OS.get_cmdline_user_args():
		package_family = "aos_mound"
	var prepared := "--prepared" in OS.get_cmdline_user_args()
	var package_path := "res://local-art/creatures/%s/preparation.json" % package_family
	var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(package_path))
	for record: Dictionary in package.models:
		var family := str(record.family)
		var body := int(record.bodies[0].body)
		var expected := record.duplicate(true)
		if prepared:
			Registry.entries[body] = record
		else:
			expected.status = "validated"
		assert(Registry.supports_body(body) and Registry.entry(body) == expected)
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
		var actions := (ANIMAL if family == "ferret" else MONSTER).duplicate()
		if family == "dryad":
			actions.erase(2)
			actions[11] = "Pillage"
			actions[12] = "Cast"
			var cast_packet := PackedByteArray([0xe2])
			cast_packet.append_array(Wire.uint_be(serial, 4))
			cast_packet.append_array(PackedByteArray([0, 11, 0, 0, 0]))
			game._handle(cast_packet)
			assert(avatar.receive_native_action(game.last_mobile_actions[serial]))
			assert(actor.current_clip == "Cast")
			print("Dryad new-protocol casting passed")
			actions[2] = "Death"
		elif family == "hydra":
			actions.erase(2)
			actions.merge({11: "Pillage", 12: "Attack2", 18: "Fidget2", 2: "Death"})
		elif family in ["aos_creatures", "aos_aliases", "aos_mound"]:
			for group: int in actions.keys():
				if not actor.animator.has_animation(actions[group]):
					actions.erase(group)
			assert(actions.has(4) and actions.has(10) and actions.has(2))
		for group: int in actions:
			var packet := PackedByteArray([0x6e])
			packet.append_array(Wire.uint_be(serial, 4))
			packet.append_array(PackedByteArray([0, group, 0, 5, 0, 1, 1, 0, 0]))
			game._handle(packet)
			assert(avatar.receive_native_action(game.last_mobile_actions[serial]), family + " group " + str(group))
			assert(actor.current_clip == actions[group])
		for hue in [0, 0x8fd if family == "hydra" else 53, 0x8035]:
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
		print(str(record.kind) if family in ["aos_creatures", "aos_aliases", "aos_mound"] else family, " passed ", actions.size(), " decoded action routes and three static corpse hues")
	quit()
