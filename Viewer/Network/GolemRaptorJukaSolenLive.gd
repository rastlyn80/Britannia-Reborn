extends "res://Network/GoatHarpyHordeLive.gd"

func reply(sex: int, command: String, prefix: String) -> String:
	var response := await super.reply(sex, command, prefix)
	if command != "cleanup" or response.is_empty() or records.is_empty():
		return response
	if records[-1].native_class not in ["RedSolenWarrior", "BlackSolenWarrior"]:
		return response
	replies[sex].clear()
	sessions[sex].send_command("[CreatureCombatFlagFixture clear-acid")
	var cleared := await until(func(): return not replies[sex].is_empty())
	if not check(cleared and replies[sex][-1].begins_with("UCCREATURE|acid-cleared|")
			and int(replies[sex][-1].get_slice("|", 2)) > 0,
			"Clean the native Solen acid after checking the corpse"):
		quit(1)
	return response

func clear_fall(actor: Node3D) -> bool:
	if actor.native_body in [730, 734]:
		return super.clear_fall(actor)
	if not check(actor.dead, "Both clients enter the retained source fall"):
		return false
	actor.dead = false
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	return true

func sample_additional_actions(sex: int) -> bool:
	if not await super.sample_additional_actions(sex):
		return false
	var owned: Dictionary = death_arenas[sex].avatars
	var serial: int = owned.keys()[0]
	if owned[serial].horse_visual.native_body not in [730, 734]:
		return true
	var packets := {}
	var collect := func(packet: Dictionary, client: int) -> void:
		if int(packet.serial) == serial and packet.protocol == "new" and int(packet.type) == 11:
			packets[client] = packet
	var owner_listener := collect.bind(sex)
	var observer_listener := collect.bind(1 - sex)
	sessions[sex].mobile_action_received.connect(owner_listener)
	sessions[1 - sex].mobile_action_received.connect(observer_listener)
	var response := await super.reply(sex, "action -2", "UCCREATURE|action|")
	var received := not response.is_empty() and await until(func() -> bool: return packets.size() == 2)
	sessions[sex].mobile_action_received.disconnect(owner_listener)
	sessions[1 - sex].mobile_action_received.disconnect(observer_listener)
	if not check(received, "Original newer type 11 reaches both clients"):
		return false
	for client in [sex, 1 - sex]:
		var avatar: Node3D = death_arenas[client].avatars[serial]
		if not check(avatar.receive_native_action(packets[client]) and avatar.horse_visual.current_clip == "Attack",
				"Newer type 11 selects the original bite"):
			return false
	additional_actions[records.size()].actions.append({"requested": -2, "owner_packet": packets[sex],
		"observer_packet": packets[1 - sex], "owner_clip": "Attack", "observer_clip": "Attack"})
	return true
