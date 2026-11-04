extends SceneTree

const Registry = preload("res://Presentation/CreatureRegistry.gd")
const Avatar = preload("res://Presentation/HumanAvatar.gd")
const Game = preload("res://Network/GameSession.gd")
const Wire = preload("res://Network/LoginProtocol.gd")
const Corpses = preload("res://Presentation/CorpseModels.gd")
const MONSTER := {4:"Attack", 5:"Attack2", 6:"Attack3", 10:"Hit", 17:"Fidget", 2:"Death"}
const ANIMAL := {3:"Eat", 4:"Alert", 5:"Attack", 6:"Attack2", 7:"Hit", 11:"LieDown", 8:"Death"}
const RECOVERED_FAMILIES := ["aos_creatures", "aos_aliases", "aos_mound", "recovered_late",
	"tormented_minotaur", "late_donors", "gargoyle_vendor", "aos_armed", "aos_abysmal", "animated_weapon", "slith", "raptor", "fetid_essence", "corporeal_brume"]
const ACTION_RECIPES := {
	831: {"stem": "parrot-831-flight-trial", "slot": 19, "clip": "Fly",
		"description": "Authored wingbeat from the eight-frame preferred UOP direction",
		"reference": {"archive": "AnimationFrame4.uop", "frame_headers": 40,
			"payload_sha256": "feea55575116337dba1cbaa3b4d6f705459b9084ac173c5dc8aeb18f51620c78"}},
	267: {"stem": "troglodyte-267-reach-trial", "slot": 11, "clip": "Pillage",
		"description": "Recovered Misc reach retimed to the five-frame Classic MUL sequence",
		"reference": {"archive": "anim5.mul", "graphic": 26,
			"directional_payload_sha256": "b8cea81705fc094ede2b3bbeca4e790f29b7bdf1366c7df0606a8f46d385c78e"}},
	730: {"stem": "ready-stance-730", "shared": true, "slot": 11, "clip": "ReadyStance",
		"description": "Authored ready stance from the ten-frame preferred UOP group 25",
		"reference": {"archive": "AnimationFrame3.uop", "frame_headers": 50, "uop_group": 25, "new_type": 14,
			"payload_sha256": "64b5c5bbdb0c7ee0bbd97af107c3b30ae58a97229d43738e0d95b96ef7235d85"}},
	734: {"stem": "ready-stance-734", "slot": 11, "clip": "ReadyStance",
		"description": "Authored ready stance from the ten-frame preferred UOP group 25",
		"reference": {"archive": "AnimationFrame3.uop", "frame_headers": 50, "uop_group": 25, "new_type": 14,
			"payload_sha256": "3080bf857102a6b02d5e8d2cf64b5d74568a4068c7f2127da651c33c7dfe1e85"}},
}

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func rigid_weapon_faces(actor: Node3D, joint: String) -> int:
	var count := 0
	var bone: int = actor.skeleton.find_bone(joint)
	assert(bone >= 0)
	for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin == null or not mesh.is_visible_in_tree():
			continue
		for surface in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var stride := joints.size() / vertices.size()
			var corners := vertices.size() if indices.is_empty() else indices.size()
			for start in range(0, corners, 3):
				var weapon := true
				for corner in range(start, start + 3):
					var vertex := corner if indices.is_empty() else indices[corner]
					var index := vertex * stride
					var binding := joints[index]
					var attached := mesh.skin.get_bind_bone(binding)
					if attached < 0:
						attached = actor.skeleton.find_bone(mesh.skin.get_bind_name(binding))
					weapon = weapon and attached == bone and is_equal_approx(weights[index], 1.0)
				if weapon:
					count += 1
	return count

func run() -> void:
	Registry.load_index()
	var package_family := "hydra" if "--family=hydra" in OS.get_cmdline_user_args() else "late_source"
	for candidate: String in RECOVERED_FAMILIES:
		if "--family=" + candidate in OS.get_cmdline_user_args():
			package_family = candidate
			break
	var prepared := "--prepared" in OS.get_cmdline_user_args()
	var package_path := "res://local-art/creatures/%s/preparation.json" % package_family
	var package: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(package_path))
	for record: Dictionary in package.models:
		var family := str(record.family)
		var body := int(record.bodies[0].body)
		var expected := record.duplicate(true)
		var action: Dictionary = {}
		if prepared:
			Registry.entries[body] = record
		else:
			var active := Registry.entry(body)
			expected = preload("res://Presentation/LegacyCreatureAliasEvidence.gd").expected_package(record, active)
			if active.has("uop_redirect_native_sha256"):
				expect_uop_redirects(expected, active, body)
			if ACTION_RECIPES.has(body) and active.has("classic_gesture_native_sha256"):
				action = ACTION_RECIPES[body]
				expect_recovered_action(expected, active, body, action)
		assert(Registry.supports_body(body) and Registry.entry(body) == expected)
		var avatar := Avatar.new()
		avatar.initial_body = body
		root.add_child(avatar)
		avatar.set_physics_process(false)
		var actor: Node3D = avatar.horse_visual
		assert(actor != null and avatar.human_visual == null)
		if family == "aos_armed":
			var part: Dictionary = record.rigid_import.parts[0]
			var refinement := int(record.stats.rounded.triangles) / int(record.stats.original.triangles)
			var bound_faces := rigid_weapon_faces(actor, part.name)
			assert(bound_faces == int(part.triangles) * refinement, "%s rigid faces: %d expected %d" % [record.kind, bound_faces, int(part.triangles) * refinement])
			var weapon_joint: int = actor.skeleton.find_bone(part.name)
			actor.play("Attack", 0.0)
			actor.animator.seek(0.0, true)
			actor.skeleton.force_update_all_bone_transforms()
			var start: Transform3D = actor.skeleton.get_bone_global_pose(weapon_joint)
			actor.animator.seek(actor.animator.current_animation_length * 0.4, true)
			actor.skeleton.force_update_all_bone_transforms()
			assert(not start.is_equal_approx(actor.skeleton.get_bone_global_pose(weapon_joint)))
		actor.set_process(false)
		actor.set_physics_process(false)
		var serial := 0x1234
		var entity := {"serial": serial, "body": body, "hue": 0}
		var game := Game.new()
		root.add_child(game)
		game.set_process(false)
		game.entities[serial] = entity
		var actions := (ANIMAL if family == "ferret" or record.bodies[0].native_profile == "animal" else MONSTER).duplicate()
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
		elif family in RECOVERED_FAMILIES:
			if expected.has("legacy_slot11_evidence"):
				var death_slot := 8 if record.bodies[0].native_profile == "animal" else 2
				var death: String = actions[death_slot]
				actions.erase(death_slot)
				actions[11] = "Fidget"
				actions[death_slot] = death
			for group: int in actions.keys():
				actions[group] = record.get("classic_action_categories", {}).get(str(group), actions[group])
				if not actor.animator.has_animation(actions[group]):
					actions.erase(group)
			assert("Attack" in actions.values() and "Hit" in actions.values() and "Death" in actions.values())
		if not action.is_empty():
			var death: String = actions[2]
			actions.erase(2)
			actions[action.slot] = action.clip
			actions[2] = death
		for group: int in actions:
			var packet := PackedByteArray([0x6e])
			packet.append_array(Wire.uint_be(serial, 4))
			packet.append_array(PackedByteArray([0, group, 0, 5, 0, 1, 1, 0, 0]))
			game._handle(packet)
			assert(avatar.receive_native_action(game.last_mobile_actions[serial]), family + " group " + str(group))
			assert(actor.current_clip == actions[group], "%s group %d expected %s, got %s" % [record.kind, group, actions[group], actor.current_clip])
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
		print(str(record.kind) if family in RECOVERED_FAMILIES else family, " passed ", actions.size(), " decoded action routes and three static corpse hues")
	quit()

func expect_recovered_action(expected: Dictionary, active: Dictionary, body: int, recipe: Dictionary) -> void:
	assert(active.classic_gesture_base_assets == expected.assets)
	var reference: Dictionary = active.authored_action_reference
	assert(int(reference.body) == body and int(reference.group) == recipe.slot)
	for key: String in recipe.reference:
		assert(reference[key] == recipe.reference[key])
	for treatment: String in expected.assets.keys():
		var suffix: String = "shared" if recipe.get("shared", false) else treatment
		var path := "res://local-art/creatures/%s-%s.scn" % [recipe.stem, suffix]
		assert(active.assets[treatment] == path and active.authored_action_scene_sha256[treatment] == FileAccess.get_sha256(path))
	expected.classic_gesture_base_assets = expected.assets
	expected.classic_gesture_native_sha256 = active.classic_gesture_native_sha256
	expected.authored_action_reference = reference
	expected.authored_action_scene_sha256 = active.authored_action_scene_sha256
	expected.assets = active.assets
	expected.asset_sha256 = active.authored_action_scene_sha256
	expected.import_sha256 = {}
	expected.classic_action_categories = expected.get("classic_action_categories", {}).merged({str(recipe.slot): recipe.clip}, true)
	if recipe.reference.has("new_type"):
		expected.new_action_categories = expected.get("new_action_categories", {}).merged({
			str(recipe.reference.new_type): recipe.clip}, true)
	expected.authored_replacements = expected.get("authored_replacements", {}).merged({
		recipe.clip: recipe.description}, true)
	for key in ["validation_sha256", "gpu_sha256", "gpu_runtime_sha256"]:
		expected.erase(key)

func expect_uop_redirects(expected: Dictionary, active: Dictionary, body: int) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../scripts/creature-uop-redirects.json"))
	var proof: Dictionary = manifest.bodies[str(body)]
	assert(proof.kind == expected.kind and proof.targets == active.uop_redirect_targets)
	var overrides: Dictionary = expected.get("classic_action_categories", {}).duplicate()
	for target: Dictionary in proof.targets.values():
		for slot: int in target.slots:
			overrides[str(slot)] = target.clip
	expected.classic_action_categories = overrides
	expected.uop_redirect_targets = proof.targets
	expected.uop_redirect_native_sha256 = active.uop_redirect_native_sha256
