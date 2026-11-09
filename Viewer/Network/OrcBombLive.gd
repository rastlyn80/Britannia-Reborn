extends "res://Network/FluidElementalBehaviourLive.gd"

const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Effects := preload("res://Presentation/CreatureEffectPresenter.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const INPUT := "res://../work/creatures/bomber_ogre_rune_dopple_actions/prepared-client.json"
const OUTPUT := "res://../outputs/creatures/bomber_ogre_rune_dopple_actions/bomb.json"

class Arena extends Node3D:
	var avatars := {}
	var game: Node

func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func reply(client: int, command: String) -> String:
	replies[client].clear()
	sessions[client].send_command("[OrcBombFixture " + command)
	assert(await until(func(): return not replies[client].is_empty()), command)
	return replies[client][-1]

func run() -> void:
	var pin := FileAccess.get_sha256(INPUT)
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(INPUT))
	var candidates := rows.filter(func(row: Dictionary) -> bool: return int(row.bodies[0].body) == 182)
	assert(candidates.size() == 1)
	var record: Dictionary = candidates[0]
	assert(record.status == "prepared" and record.family == "bomber_ogre_rune_dopple_actions" and record.kind == Registry.entry(182).kind)
	var source_hashes := {}
	for treatment: String in record.assets:
		source_hashes[treatment] = FileAccess.get_sha256(record.assets[treatment])
	assert(source_hashes == record.authored_action_scene_sha256)
	Registry.entries[182] = record
	var accounts: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../work/horse-session/accounts.local.json"))
	for client in 2:
		var session := Game.new()
		root.add_child(session)
		sessions.append(session)
		session.failed.connect(func(reason: String): errors.append(reason))
		session.message_received.connect(func(message: String):
			if message.begins_with("UCBOMB|"):
				replies[client].append(message))
		session.connect_account(accounts[client].username, accounts[client].password, 2594)
		assert(await until(func(): return session.phase == "characters"))
		var slot := -1
		var city := -1
		for place: Dictionary in session.cities:
			if place.name == "Britain":
				city = int(place.index)
		for character: Dictionary in session.characters:
			if str(character.name).is_empty():
				slot = int(character.slot)
				break
		assert(slot >= 0 and city >= 0)
		session.create_character("Bomber Observer %s" % ("Two" if client else "One"), slot, city, client == 1)
		assert(await until(func(): return session.phase == "world"))
	# Move the second disposable account to the same fixture arena before the trial.
	assert((await reply(1, "prepare")).begins_with("UCBOMB|prepared|"))
	assert(await reply(1, "cleanup") == "UCBOMB|clean")
	var prepared := (await reply(0, "prepare")).split("|")
	assert(prepared.size() == 5 and prepared[1] == "prepared" and int(prepared[4]) == 182)
	var serial := int(prepared[2])
	var target_serial := int(prepared[3])
	var witnessed := {}
	var action_count := [0, 0]
	for client in 2:
		var session: Node = sessions[client]
		assert(await until(func(): return session.entities.has(serial) and session.entities.has(target_serial)))
		var arena := Arena.new()
		root.add_child(arena)
		arena.game = session
		var avatar := Avatar.new()
		avatar.initial_body = 182
		arena.add_child(avatar)
		avatar.set_physics_process(false)
		avatar.apply_server_appearance(session.entities[serial], [])
		var creature: Node3D = avatar.horse_visual
		assert(creature.native_body == 182)
		arena.avatars[serial] = avatar
		var target := Node3D.new()
		arena.add_child(target)
		target.position = Vector3(3, 0, 0)
		arena.avatars[target_serial] = target
		var effects := Effects.new()
		arena.add_child(effects)
		effects.scene = arena
		session.mobile_action_received.connect(func(request: Dictionary):
			if int(request.serial) == serial:
				action_count[client] += 1)
		session.module("effects").spawned.connect(func(effect: Dictionary):
			if int(effect.source) != serial or int(effect.graphic) != 0x1c19:
				return
			assert(effect.kind == "moving" and int(effect.target) == target_serial and effect.explodes
				and int(effect.speed) == 1 and int(effect.duration) == 0, str(effect))
			if effect.has("tile"):
				assert(int(effect.tile) == 9502 and int(effect.explode_effect) == 6014 and int(effect.explode_sound) == 0x11d)
			var root_before: Transform3D = creature.global_transform
			var rig: Skeleton3D = creature.skeleton
			var palm := rig.to_global(rig.get_bone_global_pose(rig.find_bone("cp_grasp_rhand")).origin)
			effects.present(effect)
			assert(effects.get_child_count() == 1 and creature.current_clip == "BombFollowThrough")
			var projectile: Node3D = effects.get_child(0)
			assert(projectile.global_position.is_equal_approx(palm) and creature.global_transform == root_before)
			witnessed[client] = effect)
	assert((await reply(0, "throw")).begins_with("UCBOMB|throw|"))
	assert(await until(func(): return witnessed.size() == 2))
	var before := (await reply(0, "hits")).split("|")
	assert(before.size() == 4 and int(before[2]) == int(before[3]))
	await create_timer(1.15).timeout
	var after := (await reply(0, "hits")).split("|")
	assert(after.size() == 4 and int(after[2]) > int(after[3]))
	assert(await reply(0, "cleanup") == "UCBOMB|clean")
	assert(action_count == [0, 0], str(action_count))
	assert(FileAccess.get_sha256(INPUT) == pin)
	for session in sessions:
		session.close()
	var output := FileAccess.open(OUTPUT, FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify({"body": 182, "client_effects": witnessed, "animation_packets": action_count,
		"hits_before": int(before[3]), "hits_after": int(after[3]), "scene_sha256": source_hashes, "candidate_sha256": pin,
		"check_sha256": FileAccess.get_sha256(get_script().resource_path),
		"presenter_sha256": FileAccess.get_sha256("res://Presentation/CreatureEffectPresenter.gd"),
		"renderer_sha256": FileAccess.get_sha256("res://Presentation/OrcBomberActionsVisual.gd"),
		"native_sha256": FileAccess.get_sha256("res://../Server/ModernUO/Projects/UOContent/Mobiles/Monsters/Humanoid/Melee/OrcBomber.cs"),
		"scope": "Native OrcBomber.ThrowBomb and unmodified damage timer on disposable server. Both clients witness the effect and hand origin. Fixture selection of target."}, "\t"))
	output.close()
	print("ORC BOMBER NATIVE: both clients witness the right-hand bomb projectile and real delayed damage, with no server animation packet")
	quit()
