extends SceneTree

const Registry = preload("res://Presentation/CreatureRegistry.gd")
const Avatar = preload("res://Presentation/HumanAvatar.gd")
const Game = preload("res://Network/GameSession.gd")
const Wire = preload("res://Network/LoginProtocol.gd")
const Corpses = preload("res://Presentation/CorpseModels.gd")
const PACKAGE := "res://local-art/creatures/vampire_bat/preparation.json"
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
		var expected_record := record.duplicate(true)
		expected_record.status = "validated"
		var active := Registry.entry(body)
		assert(Registry.supports_body(body))
		if active.has("classic_gesture_native_sha256"):
			var proof := "res://../work/creatures/vampire_bat_actions/accepted-native/"
			var base: Array = JSON.parse_string(FileAccess.get_file_as_string(proof + "base-rows.json"))
			assert(base == [expected_record])
			var prior_assets: Dictionary = expected_record.assets
			if active.get("classic_gesture_batch") == "later_creature_gestures":
				var wing_routes: Array = JSON.parse_string(FileAccess.get_file_as_string(proof + "candidates.json"))
				assert(not wing_routes.is_empty())
				prior_assets = wing_routes[0].presentation.assets
				for row: Dictionary in wing_routes:
					assert(int(row.body) == body and row.presentation.assets == prior_assets)
			assert(active.classic_gesture_base_assets == prior_assets)
		else:
			assert(active == expected_record)
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
		var actions := {0:"Walk",1:"Idle",4:"Attack",5:"Attack2",6:"Attack3",10:"Hit",17:"Fidget",19:"Fly",2:"Death"}
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
			if group == 19: assert(not actor.contact.enabled)
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
