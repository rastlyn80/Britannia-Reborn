extends "res://Network/OstardLive.gd"

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Avatar := preload("res://Presentation/HumanAvatar.gd")
const BeetleVisual := preload("res://Presentation/SourceBeetleRestVisual.gd")
const BODY := 791
const TRIAL := "res://../work/creatures/giant_beetle_rest/preview.json"
const OUTPUT := "res://../outputs/ostard-riding/giant-beetle-rest-live.json"
var rest_records: Array[Dictionary] = []
var mounted_sexes := {}
var tested_package_sha256: String

func run() -> void:
	assert("--giant-beetle" in OS.get_cmdline_user_args())
	var candidate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TRIAL))
	assert(candidate.kind == "giant_beetle" and candidate.status == "prepared" and candidate.bodies.size() == 1)
	assert(int(candidate.bodies[0].body) == BODY and int(candidate.mount_item) == 0x3ebc)
	for treatment: String in candidate.assets:
		var path: String = candidate.assets[treatment]
		assert(path.begins_with("res://local-art/creatures/") and path.ends_with(".scn"))
		assert(FileAccess.get_sha256(path) == candidate.authored_action_scene_sha256[treatment])
	tested_package_sha256 = FileAccess.get_sha256(TRIAL)
	Registry.load_index()
	Registry.entries[BODY] = candidate
	await super.run()
	if not check(rest_records.size() == 2 and mounted_sexes.size() == 2, "Both riders and both rest perspectives were sampled"):
		return
	var native: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../outputs/ostard-riding/giant-beetle-live.json"))
	native.rest_records = rest_records
	native.prepared_package_sha256 = tested_package_sha256
	native.wrapper_sha256 = FileAccess.get_sha256(get_script().resource_path)
	var output := FileAccess.open(OUTPUT, FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify(native, "\t"))
	output.close()

func native_step(session: Node, running: bool, desired: int = -1) -> int:
	var sex := sessions.find(session)
	if not mounted_sexes.has(sex):
		var mount: Node3D = avatars[sex].horse_visual
		if not check(mount is BeetleVisual, "Mounted equipment selects the fitted Beetle scene"):
			return -1
		mounted_sexes[sex] = true
	return await super.native_step(session, running, desired)

func beetle_pack(session: Node, sex: int, serial: int) -> bool:
	if not await super.beetle_pack(session, sex, serial):
		return false
	var peer: Node = sessions[1 - sex]
	var clients: Array[Node] = [session, peer]
	for client: Node in clients:
		client.last_mobile_actions.erase(serial)
	replies[sex].clear()
	session.send_command("[GiantBeetleRestFixture %d" % serial)
	var witnessed := await until(func() -> bool:
		return replies[sex].has("UCEQUINE|beetle-rest|%d" % serial) and clients.all(func(client: Node) -> bool:
			var packet: Dictionary = client.last_mobile_actions.get(serial, {})
			return packet.get("protocol") == "classic" and int(packet.get("action", -1)) == 11))
	if not check(witnessed, "Both clients receive the Classic rest packet after native dismount: " + str(replies[sex])):
		return false
	var packets: Array[Dictionary] = []
	for client: Node in clients:
		var packet: Dictionary = client.last_mobile_actions[serial]
		var avatar := Avatar.new()
		avatar.initial_body = BODY
		root.add_child(avatar)
		avatar.set_physics_process(false)
		avatar.apply_server_appearance(client.entities[serial], [])
		var beetle: Node3D = avatar.horse_visual
		beetle.set_process(false)
		var played := avatar.receive_native_action(packet)
		var rests: bool = beetle.current_clip == "LieDown" and not beetle.dead and beetle.contact.enabled
		beetle._process(beetle.action_remaining + 0.1)
		var holds: bool = not beetle.animator.is_playing()
		beetle.play_gait(true, 2.0)
		var walks: bool = beetle.current_clip == "Walk"
		avatar.free()
		if not check(played and rests and holds and walks, "Fitted Beetle rest holds upright until movement resumes"):
			return false
		packets.append(packet)
	rest_records.append({"female": sex == 1, "serial": serial, "packets": packets})
	return true
