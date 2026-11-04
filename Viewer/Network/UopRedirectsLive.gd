extends "res://Network/CreatureLive.gd"
## Check each redirected slot on both live clients as part of the standard native suite.

const INPUT := "res://../work/creatures/live-candidates.json"
const REPORT := "res://../outputs/creatures/uop_redirects/live.json"
var redirect_records: Array[Dictionary] = []

func _initialize() -> void:
	family = "uop_redirects"
	create_timer(150.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string(INPUT))
	assert(not candidates.is_empty())
	Registry.load_index()
	for candidate: Dictionary in candidates:
		var body := int(candidate.body)
		var row: Dictionary = candidate.presentation
		assert(row.status == "prepared" and row.family == family and row.kind == Registry.entry(body).kind)
		assert(row.bodies.size() == 1 and int(row.bodies[0].body) == body)
		assert(not row.uop_redirect_targets.is_empty())
		Registry.entries[body] = row
	await super.run()
	if records.size() != 2 * candidates.size() or records.size() != redirect_records.size():
		quit(1)
		return
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(REPORT))
	assert(report.records.size() == records.size() and report.candidate_sha256 == candidate_pin)
	for index in report.records.size():
		var witness := redirect_records[index]
		assert(report.records[index].body == witness.body and report.records[index].female == witness.female)
		report.records[index].uop_redirects = witness.actions
	report.prepared_trial = true
	report.prepared_wrapper_sha256 = FileAccess.get_sha256(get_script().resource_path)
	var output := FileAccess.open(REPORT, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()

func reply(sex: int, command: String, prefix: String) -> String:
	if command == "action 4" and not await check_redirects(sex):
		return ""
	return await super.reply(sex, command, prefix)

func check_redirects(sex: int) -> bool:
	var avatars: Dictionary = death_arenas[sex].avatars
	if not check(avatars.size() == 1, "One active avatar for this native redirect witness"):
		return false
	var serial: int = avatars.keys()[0]
	var owner: Node3D = avatars[serial]
	var observer: Node3D = death_arenas[1 - sex].avatars[serial]
	var body: int = owner.horse_visual.native_body
	var targets: Dictionary = owner.horse_visual.entry.uop_redirect_targets
	var actions: Array[Dictionary] = []
	for target: Dictionary in targets.values():
		for slot: int in target.slots:
			var packets := {}
			var collect := func(packet: Dictionary, client: int):
				if int(packet.serial) == serial and packet.protocol == "classic" and int(packet.action) == slot:
					packets[client] = packet
			var owner_listener := collect.bind(sex)
			var peer_listener := collect.bind(1 - sex)
			sessions[sex].mobile_action_received.connect(owner_listener)
			sessions[1 - sex].mobile_action_received.connect(peer_listener)
			var response := await super.reply(sex, "action %d" % slot, "UCCREATURE|action|")
			var both_received := not response.is_empty() and await until(func(): return packets.size() == 2)
			sessions[sex].mobile_action_received.disconnect(owner_listener)
			sessions[1 - sex].mobile_action_received.disconnect(peer_listener)
			if not check(both_received, "Both native clients receive body %d classic slot %d" % [body, slot]):
				return false
			var owner_ok: bool = owner.receive_native_action(packets[sex]) and owner.horse_visual.current_clip == target.clip
			var observer_ok: bool = observer.receive_native_action(packets[1 - sex]) and observer.horse_visual.current_clip == target.clip
			if not check(owner_ok and observer_ok, "Both body %d avatars play %s for slot %d" % [body, target.clip, slot]):
				return false
			actions.append({"slot": slot, "owner_clip": owner.horse_visual.current_clip,
				"observer_clip": observer.horse_visual.current_clip})
	redirect_records.append({"body": body, "female": sex == 1, "actions": actions})
	return true
