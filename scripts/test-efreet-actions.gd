extends "res://../scripts/test-mage-lord-tentacle-actions.gd"

const PACKAGE := "efreet_actions"
const EFREET := 131
const HOVER_HEIGHTS := [0.94, 1.36, 0.69]
const CLASSIC := {0:"Walk", 1:"Idle", 4:"Attack", 5:"EfreetPalmSweep", 6:"EfreetReverseStrike",
	7:"EfreetOverhead", 8:"EfreetHeldReach", 10:"Hit", 11:"EfreetGuardBend", 12:"Cast",
	15:"EfreetSideRecoil", 16:"EfreetChestBrace", 17:"Fidget", 18:"EfreetOpenArms"}
const MODERN := [[0, 0, 0, "Attack"], [0, 0, 1, "EfreetPalmSweep"], [0, 0, 2, "Attack"],
	[0, 1, 1, "Attack"], [0, 2, 1, "Attack"], [0, 9, 1, "Attack"], [0, 8, 1, "EfreetPalmSweep"],
	[2, 0, 0, "EfreetSideRecoil"], [4, 0, 0, "Hit"], [11, 0, 0, "Cast"], [14, 0, 0, "EfreetGuardBend"],
	[3, 0, 0, "Death"], [3, 0, 1, "Death2"]]

static func install_efreet() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(
			"res://../work/creatures/%s/prepared-client.json" % PACKAGE))
		assert(rows.size() == 1 and int(rows[0].bodies[0].body) == EFREET and rows[0].status == "prepared")
		Registry.entries[EFREET] = rows[0]
	else:
		assert(Registry.entry(EFREET).get("classic_gesture_batch") == PACKAGE)
	assert(Registry.entry(13).kind == "air_elemental")

func run() -> void:
	install_efreet()
	var session := Game.new()
	root.add_child(session)
	session.set_process(false)
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(EFREET, hue)
		assert(corpse.get_meta("corpse_body") == EFREET and corpse.get_meta("native_hue") == hue
			and corpse.get_meta("death_clip") == "Death" and corpse.get_meta("static_cadaver"))
		corpse.free()
	for index in SLOPES.size():
		var plane := await support(SLOPES[index])
		for treatment: String in TREATMENTS:
			sample_efreet(session, plane, treatment, HOVER_HEIGHTS[index])
		plane.free()
		await physics_frame
	assert(checked == 4131)
	print("EFREET: ", checked, " decoded Classic and newer poses, exact source keys and three corpse hues")
	quit()

func sample_efreet(session: Node, plane: StaticBody3D, treatment: String, height: float) -> void:
	var actor := Registry.create(EFREET)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(EFREET, 0x8035)
	actor.position.y = height
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	assert(actor.skeleton.get_bone_count() == 30 and actor.native_hue == 0x8035)
	if plane.rotation == Vector3.ZERO:
		Earlier.check_earlier_keys(player, Registry.entry(EFREET).classic_gesture_base_assets[treatment])
	for slot: int in CLASSIC:
		measure(actor, plane, decode(session, EFREET, slot), CLASSIC[slot])
	for action: Array in MODERN:
		measure(actor, plane, decode_new(session, EFREET, action[0], action[1], action[2]), action[3])
	for kind: int in [5, 8, 15]:
		var unsupported := decode_new(session, EFREET, kind, 0, 0)
		assert(not actor.receive_action(unsupported) and actor.get_meta("unsupported_action") == unsupported)
	actor.free()

func measure(actor: Node3D, plane: StaticBody3D, request: Dictionary, expected: String) -> void:
	actor.model.position -= actor.fall.shift
	actor.fall.shift = Vector3.ZERO
	actor.fall.plane = {}
	actor.dead = false
	var anchor := actor.global_transform
	var player: AnimationPlayer = actor.animator
	player.stop()
	assert(actor.receive_action(request) and actor.current_clip == expected and actor.get_meta("native_action") == request)
	if request.protocol == "new":
		assert(is_equal_approx(actor.action_remaining, player.get_animation(expected).length))
	player.advance(0.15)
	for step in 17:
		player.seek(player.current_animation_length * step / 16.0, true)
		actor._physics_process(1.0 / 60.0)
		var gap := Ground.minimum_plane_gap(actor.skin, actor.skeleton, actor.skeleton.global_transform,
			plane.global_position, plane.global_basis.y.normalized())
		assert(actor.global_transform == anchor and gap >= (0.0015 if actor.dead else 0.25),
			"Efreet %s %s pose %s gap %s" % [actor.treatment, expected, step, gap])
		checked += 1

static func decode_new(session: Node, serial: int, kind: int, subaction: int, variation: int) -> Dictionary:
	var packet := PackedByteArray([0xe2])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(Wire.uint_be(kind, 2))
	packet.append_array(Wire.uint_be(subaction, 2))
	packet.append(variation)
	session._handle(packet)
	return session.last_mobile_actions[serial]
