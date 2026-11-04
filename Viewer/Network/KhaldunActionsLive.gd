extends "res://Network/KhaldunDoomLive.gd"
## Run the original native identity checks and independently witness additional actions.

const Avatar := preload("res://Presentation/HumanAvatar.gd")
const BASE_TEST := "res://Network/KhaldunDoomLive.gd"
const EXTENSION := "res://../Server/HorseIntegrationFixtures/KhaldunActionFixtures.cs"
var acting_serial := 0
var candidate_row: Dictionary
var actors: Array[Node3D] = []
var additional: Array[Array] = []

func _initialize() -> void:
	family = "khaldun_actions"
	prepared = true
	create_timer(180.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	await super.run()
	if records.size() != 4 or additional.size() != records.size():
		quit(1)
		return
	var path := "res://../outputs/creatures/%s/live.json" % family
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for index in report.records.size():
		report.records[index].classic_actions = additional[index]
	report.base_test_sha256 = FileAccess.get_sha256(BASE_TEST)
	report.extension_sha256 = FileAccess.get_sha256(EXTENSION)
	var output := FileAccess.open(path, FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()

func check_creature(sex: int, candidate: Dictionary) -> bool:
	actors.clear()
	acting_serial = 0
	candidate_row = candidate.presentation
	var capture := func(child: Node):
		if child is Avatar and child.initial_body == int(candidate.body):
			actors.append(child)
	root.child_entered_tree.connect(capture)
	var passed := await super.check_creature(sex, candidate)
	root.child_entered_tree.disconnect(capture)
	return passed

func reply(sex: int, command: String, prefix: String) -> String:
	if command == "kill" and not await check_actions(sex):
		return ""
	var result := await super.reply(sex, command, prefix)
	if command.begins_with("prepare ") and not result.is_empty():
		acting_serial = int(result.split("|")[2])
	return result

func check_actions(sex: int) -> bool:
	if not check(actors.size() == 2 and acting_serial > 0, "Two actual avatars for the checked native subject"):
		return false
	var records_for_actor: Array[Dictionary] = []
	for group: String in candidate_row.action_witness_frames:
		var slot := int(group)
		var frames := int(candidate_row.action_witness_frames[group])
		var expected: String = candidate_row.classic_action_categories[group]
		var observed := {}
		var listener := func(packet: Dictionary, client: int):
			if int(packet.serial) == acting_serial and packet.protocol == "classic" and int(packet.action) == slot:
				observed[client] = packet
		var first := listener.bind(0)
		var second := listener.bind(1)
		sessions[0].mobile_action_received.connect(first)
		sessions[1].mobile_action_received.connect(second)
		var expected_reply := "UCCREATURE|khaldun-action|%d|%d|%d" % [acting_serial, slot, frames]
		replies[sex].clear()
		sessions[sex].send_command("[KhaldunActionFixture %d %d %d" % [acting_serial, slot, frames])
		var received := await until(func():
			return (observed.size() == 2 and replies[sex].has(expected_reply)
				or replies[sex].any(func(message: String): return message.begins_with("UCCREATURE|blocked|"))))
		sessions[0].mobile_action_received.disconnect(first)
		sessions[1].mobile_action_received.disconnect(second)
		if not check(received and observed.size() == 2 and replies[sex].has(expected_reply),
				"Exact Classic group %d and %d frames reach both clients" % [slot, frames]): return false
		for index in 2:
			# These are explicit fixture actions on a living server subject.
			actors[index].horse_visual.dead = false
			if not check(int(observed[index].frames) == frames and actors[index].receive_native_action(observed[index])
					and actors[index].horse_visual.current_clip == expected,
					"Group %d selects %s on client %d" % [slot, expected, index]): return false
		records_for_actor.append({"group": slot, "clip": expected, "packets": [observed[0], observed[1]]})
	additional.append(records_for_actor)
	return true
