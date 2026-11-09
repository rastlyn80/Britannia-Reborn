# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Network/OstardLive.gd"

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Avatar := preload("res://Presentation/HumanAvatar.gd")
const FireVisual := preload("res://Presentation/SourceFireBeetleActionsVisual.gd")
const PREVIEW := "res://../work/creatures/fire_beetle_rest/preview.json"
const OUTPUT := "res://../outputs/ostard-riding/fire-beetle-rest-live.json"
const BODY := 169
const CLIPS := {3: "Fidget", 4: "FireBeetleLowerHead", 11: "LieDown"}
var witnesses: Array[Dictionary] = []
var mounted := {}

func run() -> void:
	assert("--fire-beetle" in OS.get_cmdline_user_args())
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PREVIEW))
	assert(entry.kind == "giant_beetle_fire" and entry.status == "prepared" and entry.bodies.size() == 1)
	assert(int(entry.bodies[0].body) == BODY and int(entry.mount_item) == 0x3e95)
	for treatment: String in entry.assets:
		assert(FileAccess.get_sha256(entry.assets[treatment]) == entry.authored_action_scene_sha256[treatment])
	var preview_hash := FileAccess.get_sha256(PREVIEW)
	var accepted := "res://local-art/creatures/accepted-index.json"
	var accepted_hash := FileAccess.get_sha256(accepted)
	Registry.load_index()
	Registry.entries[BODY] = entry
	await super.run()
	if not check(witnesses.size() == 6 and mounted.size() == 2, "Both owners and observers sampled three Fire Beetle actions"):
		return
	assert(FileAccess.get_sha256(PREVIEW) == preview_hash and FileAccess.get_sha256(accepted) == accepted_hash)
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../outputs/ostard-riding/fire-beetle-live.json"))
	report.rest_records = witnesses
	report.preview_sha256 = preview_hash
	report.wrapper_sha256 = FileAccess.get_sha256(get_script().resource_path)
	var output := FileAccess.open(OUTPUT, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()

func native_step(session: Node, running: bool, desired: int = -1) -> int:
	var sex := sessions.find(session)
	if not mounted.has(sex):
		if not check(avatars[sex].horse_visual is FireVisual, "Mount equipment selects the fitted Fire Beetle renderer"):
			return -1
		mounted[sex] = true
	return await super.native_step(session, running, desired)

func fire_beetle_smelt(session: Node, sex: int, serial: int) -> bool:
	if not await super.fire_beetle_smelt(session, sex, serial):
		return false
	var actors: Array[Node3D] = []
	for client: Node in sessions:
		var avatar := Avatar.new()
		avatar.initial_body = BODY
		root.add_child(avatar)
		avatar.set_physics_process(false)
		avatar.apply_server_appearance(client.entities[serial], [])
		avatar.horse_visual.set_process(false)
		actors.append(avatar)
	for group: int in CLIPS:
		if not await observe_group(sex, serial, group, actors):
			return false
	for avatar: Node3D in actors:
		avatar.free()
	return true

func observe_group(sex: int, serial: int, group: int, actors: Array[Node3D]) -> bool:
	var received := {}
	var collect := func(packet: Dictionary, client: int) -> void:
		if packet.protocol == "classic" and int(packet.serial) == serial and int(packet.action) == group:
			received[client] = packet
	var listeners := [collect.bind(0), collect.bind(1)]
	for client: int in [0, 1]:
		sessions[client].mobile_action_received.connect(listeners[client])
	var marker := "UCEQUINE|fire-beetle-rest|%d|%d" % [serial, group]
	replies[sex].clear()
	sessions[sex].send_command("[FireBeetleRestFixture %d %d" % [serial, group])
	var complete := await until(func(): return replies[sex].has(marker) and received.size() == 2)
	for client: int in [0, 1]:
		sessions[client].mobile_action_received.disconnect(listeners[client])
	if not check(complete, "Both clients receive Fire Beetle group %d after dismount" % group):
		return false
	for client: int in [0, 1]:
		var avatar := actors[client]
		var visual: Node3D = avatar.horse_visual
		if not check(avatar.receive_native_action(received[client]) and visual.current_clip == CLIPS[group],
				"Fitted Fire Beetle selects " + CLIPS[group]):
			return false
		if group == 11:
			var rests: bool = not visual.dead and visual.contact.enabled
			visual._process(visual.action_remaining + 0.1)
			var holds: bool = visual.current_clip == "LieDown" and not visual.animator.is_playing()
			visual.play_gait(true, 2.0)
			if not check(rests and holds and visual.current_clip == "Walk", "Rest holds upright until native movement resumes"):
				return false
	witnesses.append({"female": sex == 1, "serial": serial, "group": group,
		"clip": CLIPS[group], "packets": [received[0], received[1]]})
	return true
