extends "res://Network/GoatHarpyHordeLive.gd"

func sample_additional_actions(sex: int) -> bool:
	if not await super.sample_additional_actions(sex):
		return false
	var owned: Dictionary = death_arenas[sex].avatars
	var serial: int = owned.keys()[0]
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
	if not check(received, "Slith's original newer type 11 reaches both clients"):
		return false
	for client in [sex, 1 - sex]:
		var avatar: Node3D = death_arenas[client].avatars[serial]
		if not check(avatar.receive_native_action(packets[client]) and avatar.horse_visual.current_clip == "Attack",
				"Slith's newer type 11 plays the original bite category"):
			return false
	additional_actions[records.size()].actions.append({"requested": -2, "owner_packet": packets[sex],
		"observer_packet": packets[1 - sex], "owner_clip": "Attack", "observer_clip": "Attack"})
	return true
