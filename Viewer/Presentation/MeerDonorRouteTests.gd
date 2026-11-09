extends SceneTree

const SealedBase := preload("res://Presentation/SealedCreatureActionBase.gd")
const Registry = preload("res://Presentation/CreatureRegistry.gd")
const Avatar = preload("res://Presentation/HumanAvatar.gd")
const Game = preload("res://Network/GameSession.gd")
const Wire = preload("res://Network/LoginProtocol.gd")
const Corpses = preload("res://Presentation/CorpseModels.gd")
const PACKAGE := "res://local-art/creatures/meer_donors/preparation.json"
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
		if body == 771 and active.get("classic_gesture_batch") == "frost_through_gargoyle_actions":
			active = SealedBase.retained(active, body)
			Registry.entries[body] = active
		if active.has("legacy_slot11_evidence"):
			assert(active == preload("res://Presentation/LegacyCreatureAliasEvidence.gd").expected_package(record, active))
		var avatar := Avatar.new()
		avatar.initial_body = body
		root.add_child(avatar)
		avatar.set_physics_process(false)
		var actor: Node3D = avatar.horse_visual
		assert(actor != null and avatar.human_visual == null)
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
		if body == 773:
			for graphic in [0x0f4f, 0x0f50]:
				avatar.apply_server_appearance(entity, [{"id": graphic, "layer": 2}])
				assert(is_instance_valid(actor.crossbow) and actor.crossbow.visible)
				var hand: Vector3 = actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(actor.right_grasp).origin)
				assert(actor.crossbow.to_global(actor.GRIP).distance_to(hand) < 0.0001)
			avatar.apply_server_appearance(entity, [{"id": 0x0f50, "layer": 1}])
			assert(not actor.crossbow.visible)
			avatar.apply_server_appearance(entity, [])
			assert(not actor.crossbow.visible)

		var actions := {4: "Attack", 10: "Hit", 17: "Fidget"}
		if body == 771:
			actions[5] = "Attack2"
		elif body == 770:
			actions[12] = "Cast"
			var cast_packet := PackedByteArray([0xe2])
			cast_packet.append_array(Wire.uint_be(serial, 4))
			cast_packet.append_array(PackedByteArray([0,11,0,0,0]))
			game._handle(cast_packet)
			assert(avatar.receive_native_action(game.last_mobile_actions[serial]))
			assert(actor.current_clip == "Cast")
		else:
			actions[8] = "AttackXBow"
		actions[3 if body == 771 else 2] = "Death2" if body == 771 else "Death"
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
