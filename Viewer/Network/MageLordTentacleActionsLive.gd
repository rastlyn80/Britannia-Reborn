extends "res://Network/TokunoSpiderDragonLive.gd"
## Verify the Lord's server-supplied costume through the updated pose and death renderer.

var equipped_lords: Dictionary = {}
var costume_receipts: Array[Dictionary] = []

func run() -> void:
	await super.run()
	if costume_receipts.size() != 4 or records.size() != 6:
		quit(1)
		return
	var path := "res://../outputs/creatures/%s/live.json" % family
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	report.mage_costumes = costume_receipts
	var output := FileAccess.open(path, FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()

func sample_additional_actions(sex: int) -> bool:
	var owned: Dictionary = death_arenas[sex].avatars
	if owned.size() != 1:
		return false
	var serial: int = owned.keys()[0]
	var body: int = owned[serial].horse_visual.native_body
	if body in [125, 126]:
		var garments: Dictionary = {}
		var snapshots: Dictionary = {}
		for client in [sex, 1 - sex]:
			var session: Node = sessions[client]
			if not check(await until(func(): return session.mobile_equipment.get(serial, {}).size() >= 3),
				"Both clients receive the native Lord costume"):
				return false
			var equipment: Dictionary = session.mobile_equipment[serial]
			var expected := costume(equipment.values())
			if not check(expected.has_all([22, 6, 3]) and expected[22][0] == 7939 and expected[6][0] == 5912
				and expected[3][0] == 5901 and expected[22][1] > 0 and expected[22][1] == expected[6][1],
				"The native robe, hat, sandals and matching garment dyes reach the client"):
				return false
			var avatar: Node3D = death_arenas[client].avatars[serial]
			avatar.apply_server_appearance(session.entities[serial], equipment.values())
			if not check(costume(avatar.horse_visual.server_equipment) == expected,
				"The fitted motion renderer takes the server costume"):
				return false
			garments[client] = expected
			death_presenters[client].transition_started.connect(func(killed: int, _corpse: int, visual: Node3D):
				if killed == serial:
					snapshots[client] = costume(visual.server_equipment), CONNECT_ONE_SHOT)
		equipped_lords[records.size()] = {"body":body, "female":sex == 1, "worn":garments, "death":snapshots}
	return await super.sample_additional_actions(sex)

func reply(sex: int, command: String, prefix: String) -> String:
	var response := await super.reply(sex, command, prefix)
	if command == "kill" and equipped_lords.has(records.size()) and not response.is_empty():
		var receipt: Dictionary = equipped_lords[records.size()]
		if not check(await until(func(): return receipt.death.size() == 2) and receipt.death == receipt.worn,
			"Both actual death presenters retain the same native Lord costume"):
			return ""
		costume_receipts.append(receipt)
	return response

func costume(items: Array) -> Dictionary:
	var result := {}
	for item: Dictionary in items:
		var layer := int(item.get("layer", -1))
		if layer in [22, 6, 3]:
			result[layer] = [int(item.id), int(item.hue)]
	return result
