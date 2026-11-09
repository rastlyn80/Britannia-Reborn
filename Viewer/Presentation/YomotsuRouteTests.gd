extends SceneTree

const Registry = preload("res://Presentation/CreatureRegistry.gd")
const SealedBase := preload("res://Presentation/SealedCreatureActionBase.gd")
const Avatar = preload("res://Presentation/HumanAvatar.gd")
const Game = preload("res://Network/GameSession.gd")
const Wire = preload("res://Network/LoginProtocol.gd")
const Corpses = preload("res://Presentation/CorpseModels.gd")
const PACKAGE := "res://local-art/creatures/yomotsu/preparation.json"
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
		assert(Registry.supports_body(body), family + " missing normal body route")
		assert(Registry.entry(body).get("kind") == family)
		var active := Registry.entry(body)
		var layer: String = active.get("classic_gesture_batch", "")
		var original_layer := SealedBase.retained(active, body) if layer in ["post_solen_actions", "centaur_through_essence_actions"] else active
		var reviewed := original_layer
		var fitted: bool = body == 245 and active.get("classic_gesture_batch") == "tokuno_spider_dragon_actions"
		if fitted:
			const BASE := "res://../work/creatures/tokuno_spider_dragon_actions/accepted-native/base-rows.json"
			var baseline: Array = JSON.parse_string(FileAccess.get_file_as_string(BASE))
			var warrior := baseline.filter(func(row: Dictionary) -> bool: return row.kind == family)
			assert(warrior.size() == 1)
			reviewed = warrior[0]
			assert(active.classic_gesture_base_assets == reviewed.assets and active.bodies == reviewed.bodies)
		if layer == "centaur_through_essence_actions":
			assert(reviewed == preload("res://Presentation/LegacyCreatureAliasEvidence.gd").expected_package(record, reviewed))
		elif active.has("legacy_slot11_evidence"):
			assert(active.legacy_slot11_evidence == reviewed.legacy_slot11_evidence)
			assert(reviewed == preload("res://Presentation/LegacyCreatureAliasEvidence.gd").expected_package(record, reviewed))
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
				assert(stride >= 4)
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
		if fitted:
			actions[17] = "WeaponRest"
		if body == 253:
			actions[12] = "Cast"
			var cast_packet := PackedByteArray([0xe2])
			cast_packet.append_array(Wire.uint_be(serial, 4))
			cast_packet.append_array(PackedByteArray([0,11,0,0,0]))
			game._handle(cast_packet)
			assert(avatar.receive_native_action(game.last_mobile_actions[serial]))
			assert(actor.current_clip == "Cast")
		else:
			actions[5] = "Attack2"
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
