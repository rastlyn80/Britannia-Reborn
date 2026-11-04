extends "res://Network/PreparedCreatureActionLive.gd"
## Test explicit Classic groups outside the standard native fixture list.

var additional_actions: Dictionary = {}

func run() -> void:
	await super.run()
	if records.is_empty() or additional_actions.size() != records.size():
		quit(1)
		return
	var path := "res://../outputs/creatures/%s/live.json" % family
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(report.prepared_trial and report.records.size() == records.size())
	report.prepared_base_sha256 = FileAccess.get_sha256("res://Network/PreparedCreatureActionLive.gd")
	for index in records.size():
		var witness: Dictionary = additional_actions[index]
		var record: Dictionary = report.records[index]
		assert(record.body == witness.body and record.female == witness.female)
		for action: Dictionary in witness.actions:
			assert(not record.actions.any(func(other: Dictionary) -> bool: return other.requested == action.requested))
			record.actions.append(action)
	var output := FileAccess.open(path, FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()

func reply(sex: int, command: String, prefix: String) -> String:
	if command == "kill" and not additional_actions.has(records.size()):
		if not await sample_additional_actions(sex):
			return ""
	return await super.reply(sex, command, prefix)

func sample_additional_actions(sex: int) -> bool:
	var owned: Dictionary = death_arenas[sex].avatars
	if not check(owned.size() == 1, "One fixture creature for supplementary Classic actions"):
		return false
	var serial: int = owned.keys()[0]
	var owner: Node3D = owned[serial]
	var observer: Node3D = death_arenas[1 - sex].avatars[serial]
	var entry: Dictionary = owner.horse_visual.entry
	var slots: Array = entry.get("native_extra_classic_actions", [])
	var actions: Array[Dictionary] = []
	for value: Variant in slots:
		var slot := int(value)
		if not check(slot in range(22) and entry.classic_action_categories.has(str(slot)), "Supplementary slot is an explicit Classic route"):
			return false
		var packets := {}
		var collect := func(packet: Dictionary, client: int) -> void:
			if int(packet.serial) == serial and packet.protocol == "classic" and int(packet.action) == slot:
				packets[client] = packet
		var owner_listener := collect.bind(sex)
		var observer_listener := collect.bind(1 - sex)
		sessions[sex].mobile_action_received.connect(owner_listener)
		sessions[1 - sex].mobile_action_received.connect(observer_listener)
		var response := await super.reply(sex, "action %d" % slot, "UCCREATURE|action|")
		var both_received := not response.is_empty() and await until(func() -> bool: return packets.size() == 2)
		sessions[sex].mobile_action_received.disconnect(owner_listener)
		sessions[1 - sex].mobile_action_received.disconnect(observer_listener)
		if not check(both_received, "Supplementary Classic action %d reaches both clients" % slot):
			return false
		var clip: String = entry.classic_action_categories[str(slot)]
		var owner_ok: bool = owner.receive_native_action(packets[sex]) and owner.horse_visual.current_clip == clip
		var observer_ok: bool = observer.receive_native_action(packets[1 - sex]) and observer.horse_visual.current_clip == clip
		if not check(owner_ok and observer_ok, "Both clients play %s for supplemental slot %d" % [clip, slot]):
			return false
		actions.append({"requested": slot, "owner_packet": packets[sex], "observer_packet": packets[1 - sex],
			"owner_clip": clip, "observer_clip": clip})
	additional_actions[records.size()] = {"body": owner.horse_visual.native_body, "female": sex == 1, "actions": actions}
	return true
