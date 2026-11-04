extends "res://Network/FluidElementalBehaviourLive.gd"
## Witness the native ability, timers, projectile and damage with fixture AI stopped.

const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Effects := preload("res://Presentation/EffectPresenter.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const INPUT := "res://../work/creatures/live-candidates.json"
const OUTPUT := "res://../outputs/creatures/dragon_daemon/breath.json"
const CASES := [[12, "Dragon"], [59, "Dragon"], [12, "GreaterDragon"], [59, "GreaterDragon"],
	[60, "Drake"], [61, "Drake"]]

class Arena extends Node3D:
	var avatars := {}
	var game: Node

func _initialize() -> void:
	create_timer(125.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func reply(client: int, command: String) -> String:
	replies[client].clear()
	sessions[client].send_command("[DragonBreathFixture " + command)
	assert(await until(func(): return not replies[client].is_empty()), command)
	return replies[client][-1]

func run() -> void:
	var candidate_pin := FileAccess.get_sha256(INPUT)
	var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string(INPUT))
	Registry.load_index()
	for candidate: Dictionary in candidates:
		Registry.entries[int(candidate.body)] = candidate.presentation
	var accounts: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../work/horse-session/accounts.local.json"))
	for client in 2:
		var session := Game.new()
		root.add_child(session)
		sessions.append(session)
		session.failed.connect(func(reason: String): errors.append(reason))
		session.message_received.connect(func(message: String):
			if message.begins_with("UCBREATH|"):
				replies[client].append(message))
		session.connect_account(accounts[client].username, accounts[client].password, 2594)
		assert(await until(func(): return session.phase == "characters"))
		for character: Dictionary in session.characters:
			if not str(character.name).is_empty():
				session.select_character(int(character.slot), str(character.name))
				break
		assert(await until(func(): return session.phase == "world"))
	var records := []
	for pair: Array in CASES:
		var result := await witness(int(pair[0]), str(pair[1]))
		if result.is_empty():
			quit(1)
			return
		records.append(result)
	assert(records.size() == CASES.size())
	assert(candidate_pin == FileAccess.get_sha256(INPUT))
	for session in sessions:
		session.close()
	var receipt := FileAccess.open(OUTPUT, FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({
		"records": records, "failures": 0,
		"candidate_sha256": candidate_pin,
		"native_sha256": FileAccess.get_sha256("res://../Server/ModernUO/Projects/UOContent/Mobiles/Abilities/Fire Breath/FireBreath.cs"),
		"fixture_sha256": FileAccess.get_sha256("res://../Server/HorseIntegrationFixtures/DragonBreathFixtures.cs"),
		"test_sha256": FileAccess.get_sha256(get_script().resource_path),
		"presenter_sha256": FileAccess.get_sha256("res://Presentation/EffectPresenter.gd"),
		"scope": "Native FireBreath.Trigger and timers with controlled fixture targeting. Both clients witness group 12 and 0x36D4. AI selection is not tested.",
	}, "\t"))
	receipt.close()
	print("DRAGON BREATH NATIVE: six constructor/body cases, two clients, animated muzzle and real damage")
	quit()

func witness(body: int, native_class: String) -> Dictionary:
	var prepared := (await reply(0, "prepare %d %s" % [body, native_class])).split("|")
	assert(prepared.size() == 6 and prepared[1] == "prepared" and int(prepared[4]) == body and prepared[5] == native_class)
	var serial := int(prepared[2])
	var target_serial := int(prepared[3])
	var actions := {}
	var launches := {}
	var observers := []
	for client in 2:
		var session: Node = sessions[client]
		assert(await until(func(): return session.entities.has(serial) and session.entities.has(target_serial)))
		var arena := Arena.new()
		root.add_child(arena)
		arena.game = session
		var avatar := Avatar.new()
		arena.add_child(avatar)
		avatar.apply_server_appearance(session.entities[serial], [])
		arena.avatars[serial] = avatar
		var target := Node3D.new()
		arena.add_child(target)
		target.position = Vector3(3, 0, 0)
		arena.avatars[target_serial] = target
		var effects := Effects.new()
		arena.add_child(effects)
		effects.scene = arena
		var action_listener := func(action: Dictionary):
			if int(action.serial) == serial and action.protocol == "classic" and int(action.action) == 12:
				assert(int(action.frames) == 5 and int(action.delay) == 0)
				assert(avatar.receive_native_action(action))
				actions[client] = Time.get_ticks_msec()
		var effect_listener := func(effect: Dictionary):
			if int(effect.source) != serial or int(effect.graphic) != 0x36d4:
				return
			assert(effect.kind == "moving" and int(effect.target) == target_serial and actions.has(client))
			var muzzle: Variant = avatar.horse_visual.fire_breath_origin()
			assert(muzzle is Vector3)
			effects.present(effect)
			assert(effects.get_child_count() == 1)
			var projectile: Node3D = effects.get_child(0)
			assert(projectile.global_position.is_equal_approx(muzzle))
			launches[client] = Time.get_ticks_msec() - int(actions[client])
		session.mobile_action_received.connect(action_listener)
		session.module("effects").spawned.connect(effect_listener)
		observers.append([arena, action_listener, effect_listener])
	assert((await reply(0, "fire")).begins_with("UCBREATH|fire|"))
	assert(await until(func(): return launches.size() == 2))
	for delay: int in launches.values():
		assert(delay >= 1050 and delay <= 1800, str(launches))
	var hp := (await reply(0, "hits")).split("|")
	assert(hp.size() == 4 and hp[2] == hp[3], "Damage must follow the projectile")
	await create_timer(1.15).timeout
	hp = (await reply(0, "hits")).split("|")
	assert(hp.size() == 4 and int(hp[2]) > int(hp[3]), "The native damage timer must reduce target health")
	assert(await reply(0, "cleanup") == "UCBREATH|clean")
	for client in 2:
		var session: Node = sessions[client]
		session.mobile_action_received.disconnect(observers[client][1])
		session.module("effects").spawned.disconnect(observers[client][2])
		observers[client][0].queue_free()
	var damage := int(hp[2]) - int(hp[3])
	print("NATIVE BREATH ", native_class, " ", body, " / launch ms ", launches, " / damage ", damage)
	var scene_sha := FileAccess.get_sha256(Registry.asset_path(Registry.entry(body)))
	return {"body": body, "native_class": native_class, "launch_ms": launches, "damage": damage,
		"scene_sha256": scene_sha}
