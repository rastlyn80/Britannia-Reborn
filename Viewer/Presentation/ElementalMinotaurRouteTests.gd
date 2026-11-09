extends SceneTree

const Registry = preload("res://Presentation/CreatureRegistry.gd")
const SealedBase := preload("res://Presentation/SealedCreatureActionBase.gd")
const Avatar = preload("res://Presentation/HumanAvatar.gd")
const Game = preload("res://Network/GameSession.gd")
const Wire = preload("res://Network/LoginProtocol.gd")
const Corpses = preload("res://Presentation/CorpseModels.gd")
const GroundPlane = preload("res://Presentation/BirdGroundSupport.gd")
const PACKAGE := "res://local-art/creatures/elemental_minotaur/preparation.json"
const MONSTER := {4:"Attack", 10:"Hit", 17:"Fidget", 2:"Death"}

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	Registry.load_index()
	var prepared := "--prepared" in OS.get_cmdline_user_args()
	var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE))
	for record: Dictionary in package.models:
		var family := str(record.kind)
		var body := int(record.bodies[0].body)
		if prepared:
			Registry.entries[body] = record
		assert(Registry.supports_body(body) and Registry.entry(body).kind == family)
		var active := Registry.entry(body)
		if active.get("classic_gesture_batch") == "quagmire_through_exodus_actions":
			active = SealedBase.retained(active, body)
			Registry.entries[body] = active
		var original_layer := active
		if active.get("classic_gesture_batch") in ["post_solen_actions", "lattice_through_meer_actions"]:
			original_layer = SealedBase.retained(active, body)
		if active.has("legacy_slot11_evidence"):
			assert(original_layer == preload("res://Presentation/LegacyCreatureAliasEvidence.gd").expected_package(record, original_layer))
		var avatar := Avatar.new()
		avatar.initial_body = body
		root.add_child(avatar)
		avatar.set_physics_process(false)
		var actor: Node3D = avatar.horse_visual
		assert(actor != null and avatar.human_visual == null)
		if body == 789:
			assert(actor.contact is GroundPlane)
		elif body in [241, 772]:
			assert(actor.contact.align_skinned_soles and actor.contact.feet.size() == 2)
		actor.set_process(false)
		for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var arrays := mesh.mesh.surface_get_arrays(surface)
				var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var stride := weights.size() / positions.size()
				assert(stride == 4)
				for vertex in positions.size():
					var sum := 0.0
					for slot in stride:
						sum += weights[vertex * stride + slot]
					assert(absf(sum - 1.0) < 0.001)

		actor.set_physics_process(false)
		var serial := 0x1234
		var entity := {"serial": serial, "body": body, "hue": 0}
		var game := Game.new()
		root.add_child(game)
		game.set_process(false)
		game.entities[serial] = entity
		var actions := MONSTER.duplicate()
		actions.erase(2)
		if body in [300, 241, 772]:
			actions[12] = "Cast"
			var cast_packet := PackedByteArray([0xe2])
			cast_packet.append_array(Wire.uint_be(serial, 4))
			cast_packet.append_array(PackedByteArray([0,11,0,0,0]))
			game._handle(cast_packet)
			assert(avatar.receive_native_action(game.last_mobile_actions[serial]))
			assert(actor.current_clip == "Cast")
		else:
			actions[5] = "Attack2"
		if body in [300, 305]:
			actions[19] = "Fly"
		if actor.animator.has_animation("Attack3"):
			actions[6] = "Attack3"
		actions[2] = "Death"
		for group: int in actions:
			var packet := PackedByteArray([0x6e])
			packet.append_array(Wire.uint_be(serial, 4))
			packet.append_array(PackedByteArray([0, group, 0, 5, 0, 1, 1, 0, 0]))
			game._handle(packet)
			assert(avatar.receive_native_action(game.last_mobile_actions[serial]), family + " group " + str(group))
			var expected: String = actions[group]
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
