extends "res://Network/SwampWidowJukaActionsLive.gd"

func sample_additional_actions(sex: int) -> bool:
	if not await super.sample_additional_actions(sex):
		return false
	var owned: Dictionary = death_arenas[sex].avatars
	var serial: int = owned.keys()[0]
	if owned[serial].horse_visual.native_body != 263:
		return true
	var clients := [sex, 1 - sex]
	for client: int in clients:
		sessions[client].last_mobile_actions.erase(serial)
	var response := await super.reply(sex, "action -2", "UCCREATURE|action|")
	var received := not response.is_empty() and await until(func():
		return clients.all(func(client: int):
			var packet: Dictionary = sessions[client].last_mobile_actions.get(serial, {})
			return packet.get("protocol") == "new" and int(packet.get("type", -1)) == 11))
	if not check(received, "Both clients receive Minotaur's newer attack request"):
		return false
	var witness := {"requested": -2}
	for client: int in clients:
		var side := "owner" if client == sex else "observer"
		var packet: Dictionary = sessions[client].last_mobile_actions[serial]
		var avatar: Node3D = death_arenas[client].avatars[serial]
		if not check(avatar.receive_native_action(packet) and avatar.horse_visual.current_clip == "Attack",
				"Minotaur's newer attack selects its recovered source strike"):
			return false
		witness[side + "_packet"] = packet
		witness[side + "_clip"] = avatar.horse_visual.current_clip
	additional_actions[records.size()].actions.append(witness)
	return true
