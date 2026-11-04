extends "res://Network/KhaldunActionsLive.gd"
## Witness native layer 25 before asking either renderer for a seated action.

const MountLookup := preload("res://Presentation/MountVisual.gd")
const DeathPresentation := preload("res://Presentation/CreatureDeaths.gd")
const MOUNT_FIXTURE := "res://../Server/HorseIntegrationFixtures/RestlessSoulMountFixtures.cs"
var mount_records: Dictionary = {}
var current_mount: Dictionary = {}

func _initialize() -> void:
	family = "restless_soul_mounted"
	prepared = true
	create_timer(180.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	await super.run()
	if mount_records.size() != 2:
		quit(1)
		return
	var path := "res://../outputs/creatures/%s/live.json" % family
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for record: Dictionary in report.records:
		if int(record.body) == 970:
			record.mount = mount_records[int(record.female)]
	report.mount_fixture_sha256 = FileAccess.get_sha256(MOUNT_FIXTURE)
	report.checks = checks
	var output := FileAccess.open(path, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()

func check_actions(sex: int) -> bool:
	if int(candidate_row.bodies[0].body) != 970:
		return await super.check_actions(sex)
	var equipped := await mount_command(sex, "mount", "worn")
	if equipped.is_empty():
		return false
	var fields := equipped.split("|")
	current_mount = {"horse": int(fields[3]), "body": int(fields[4]), "item": int(fields[5]),
		"graphic": int(fields[6]), "hue": int(fields[7])}
	if not check(MountLookup.horse_body(current_mount.graphic) == current_mount.body,
			"Native constructor graphic resolves to its original horse body"):
		return false
	if not await check_worn(current_mount.hue) or not await super.check_actions(sex):
		return false
	var original_visual: int = actors[0].horse_visual.mount.get_instance_id()
	if (await mount_command(sex, "dye", "dyed", " %d" % 0x47e)).is_empty():
		return false
	if not await check_worn(0x47e):
		return false
	if not check(actors[0].horse_visual.mount.get_instance_id() == original_visual,
			"Replicated dye updates the existing mounted visual"):
		return false
	for running in [false, true]:
		var response := await super.reply(sex, "step %d" % int(running), "UCCREATURE|step|")
		if response.is_empty():
			return false
		var moved := response.split("|")
		if not check(await until(func():
			return sessions.all(func(client):
				var entity: Dictionary = client.entities.get(acting_serial, {})
				return (int(entity.get("x", -1)) == int(moved[2]) and int(entity.get("y", -1)) == int(moved[3])
					and bool(entity.get("running", false)) == running))),
				"Mounted native movement and run flag replicate"):
			return false
	if (await mount_command(sex, "dismount", "loose")).is_empty():
		return false
	if not check(await until(func():
		return sessions.all(func(client):
			return (MountLookup.mount_item(client.mobile_equipment.get(acting_serial, {}).values()).is_empty()
				and client.entities.has(current_mount.horse)))),
			"Native dismount removes layer 25 and exposes the same loose horse"):
		return false
	refresh_actors()
	if not check(actors.all(func(avatar):
		return avatar.horse_visual.mount == null and avatar.horse_visual.model.visible),
			"Both renderers restore the on-foot robe and release the horse"):
		return false
	var restored := await mount_command(sex, "mount", "worn")
	if not check(not restored.is_empty() and int(restored.split("|")[3]) == current_mount.horse,
			"Native remount uses the same horse"):
		return false
	if not await check_worn(0x47e):
		return false
	current_mount.dye = 0x47e
	current_mount.moved = true
	current_mount.dismount_remount = true
	for index in 2:
		var arena := DeathArena.new()
		root.add_child(arena)
		arena.avatars[acting_serial] = actors[index]
		var items := DeathItems.new()
		arena.add_child(items)
		var deaths := DeathPresentation.new()
		arena.add_child(deaths)
		deaths.configure(arena, sessions[index], items)
		deaths.transition_started.connect(func(serial: int, corpse: int, visual: Node3D):
			if serial == acting_serial:
				death_events[index][serial] = {"corpse": corpse, "body": visual.native_body,
					"on_foot": visual.mount == null and visual.model.visible, "clip": visual.current_clip})
		death_arenas.append(arena)
	return true

func reply(sex: int, command: String, prefix: String) -> String:
	var response := await super.reply(sex, command, prefix)
	if command != "kill" or response.is_empty() or int(candidate_row.bodies[0].body) != 970:
		return response
	var corpse := int(response.split("|")[2])
	if not check(await until(func(): return death_events.all(func(events): return events.has(acting_serial))),
			"Both clients receive native death and start a visual"):
		return ""
	for events: Dictionary in death_events:
		if not check(events[acting_serial] == {"corpse": corpse, "body": 970, "on_foot": true, "clip": "Death"},
				"Mounted death creates only the on-foot ghost collapse"):
			return ""
	var state := await mount_command(sex, "death", "death")
	if not check(state.ends_with("|1|0|1"), "Native death releases the live horse and its worn item"):
		return ""
	if not check(await until(func(): return sessions.all(func(client): return client.entities.has(current_mount.horse))),
			"Both clients see the live horse released by death"):
		return ""
	current_mount.death = death_events.map(func(events): return events[acting_serial])
	current_mount.native_death_state = state
	mount_records[sex] = current_mount.duplicate(true)
	for arena: Node3D in death_arenas:
		arena.free()
	death_arenas.clear()
	if (await mount_command(sex, "cleanup", "cleaned")).is_empty():
		return ""
	return response

func mount_command(sex: int, command: String, expected: String, suffix: String = "") -> String:
	replies[sex].clear()
	sessions[sex].send_command("[GhostMountFixture %s %d%s" % [command, acting_serial, suffix])
	var prefix := "UCCREATURE|ghost-mount|%s" % expected
	var received := await until(func():
		return replies[sex].any(func(message: String):
			return message.begins_with(prefix) or message.begins_with("UCCREATURE|blocked|")))
	var matches: Array = replies[sex].filter(func(message: String): return message.begins_with(prefix))
	if not check(received and matches.size() == 1, "Native ghost mount %s: %s" % [command, replies[sex]]):
		return ""
	return matches[0]

func check_worn(hue: int) -> bool:
	if not check(await until(func():
		return sessions.all(func(client):
			var worn := MountLookup.mount_item(client.mobile_equipment.get(acting_serial, {}).values())
			return (int(worn.get("serial", -1)) == current_mount.item and int(worn.get("id", -1)) == current_mount.graphic
				and int(worn.get("hue", -1)) == hue and not client.entities.has(current_mount.horse)))),
			"Both clients receive the exact native worn graphic, serial and dye"):
		return false
	refresh_actors()
	return check(actors.all(func(avatar):
		var visual: Node3D = avatar.horse_visual
		return (visual.mount != null and visual.mount.native_hue == hue and visual.native_hue == 0x453
			and not visual.model.visible)), "Both actual ghost renderers display the independently dyed horse")

func refresh_actors() -> void:
	for index in 2:
		var client: Node = sessions[index]
		actors[index].apply_server_appearance(client.entities[acting_serial],
			client.mobile_equipment.get(acting_serial, {}).values())
