# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Wire := preload("res://Network/LoginProtocol.gd")
const Field := preload("res://../scripts/test-field-enhanced.gd")
const Cats := preload("res://../scripts/test-cat-enhanced.gd")
const SERIAL := 0x105
const BODY := 267

func _initialize() -> void:
	create_timer(60.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	assert(world.enhanced_creature_actions == enhanced)
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	var checks := 0
	for flags: int in [0, 0x40]:
		world.game._handle(mobile_packet(at, flags))
		var avatar: Node3D = world.avatars[SERIAL]
		var expected := "TroglodyteSway"
		if enhanced:
			expected = "TroglodyteSettleFidget" if flags == 0 else "TroglodyteRaisedFidget"
		world.game._handle(action_packet(5))
		assert(avatar.horse_visual.current_clip == expected)
		world.game._handle(action_packet(8))
		assert(avatar.horse_visual.current_clip == ("TroglodyteOpenReach" if enhanced else "Pillage"))
		assert(avatar.horse_visual.native_body == BODY and avatar.horse_visual.native_hue == 1109)
		checks += 3
	if "--ranked" in OS.get_cmdline_user_args():
		for form: Array in [[16, "WaterEmerge", "WaterAlert"], [17, "OrcRise", "OrcAlert"]]:
			var body: int = form[0]
			var serial := SERIAL + body
			for flags: int in [0, 0x40]:
				world.game._handle(mobile_packet(at, flags, serial, body, 0x8035))
				var avatar: Node3D = world.avatars[serial]
				var prior: String = avatar.horse_visual.current_clip
				world.game._handle(action_packet(15, serial))
				assert(avatar.horse_visual.current_clip == (form[1] if enhanced else prior))
				world.game._handle(action_packet(8, serial))
				assert(avatar.horse_visual.current_clip == (form[2] if enhanced else "Pillage"))
				assert(avatar.horse_visual.native_body == body and avatar.horse_visual.native_hue == 0x8035)
				checks += 3
	if "--kraken" in OS.get_cmdline_user_args():
		for flags: int in [0, 0x40]:
			var serial := SERIAL + 77
			world.game._handle(mobile_packet(at, flags, serial, 77, 0x481))
			var avatar: Node3D = world.avatars[serial]
			assert(avatar.horse_visual.native_body == 77 and avatar.horse_visual.native_hue == 0x481)
			var old_scene: String = avatar.horse_visual.entry.assets.modern
			assert(old_scene.ends_with("enhanced-creature-actions/77-modern.scn") == enhanced)
			var fidget := "KrakenScan" if flags == 0 else "KrakenFinThrust"
			for selection: Array in [[5, fidget, "Fidget2"], [8, "KrakenAlert", "Fidget"],
					[14, "KrakenPoise", "Fidget"], [15, "KrakenSurface", "Fidget"]]:
				world.game._handle(action_packet(selection[0], serial))
				assert(avatar.horse_visual.current_clip == selection[1 if enhanced else 2])
				checks += 1
	if "--troll" in OS.get_cmdline_user_args():
		for flags: int in [0, 0x40]:
			var serial := SERIAL + 54
			world.game._handle(mobile_packet(at, flags, serial, 54, 0x8035))
			var actor: Node3D = world.avatars[serial].horse_visual
			assert(actor.native_body == 54 and actor.native_hue == 0x8035)
			assert((actor.find_child("EnhancedAxe", true, false) != null) == enhanced)
			var fidget := "TrollWatch" if flags == 0 else "TrollRaiseAxe"
			for selection: Array in [[5, fidget, "KnuckleCheck"], [8, "TrollAlert", "KneelingSwing"],
					[11, "TrollOverheadChop", "KneelingSwing"], [15, "TrollRise", "KneelingSwing"]]:
				world.game._handle(action_packet(selection[0], serial))
				assert(actor.current_clip == selection[1 if enhanced else 2])
				checks += 1
	if "--bird" in OS.get_cmdline_user_args():
		for flags: int in [0, 0x04, 0x40, 0x44]:
			var serial := SERIAL + 6
			world.game._handle(mobile_packet(at, flags, serial, 6, 0x901))
			var actor: Node3D = world.avatars[serial].horse_visual
			assert(actor.native_body == 6 and actor.native_hue == 0x901)
			assert(actor.animator.has_animation("BirdGlance") == enhanced)
			var prior: String = actor.current_clip
			for kind: int in [2, 5, 8, 14, 15, 11]:
				var classic := "Cast" if kind == 11 else prior
				var fitted := "BirdGlance" if kind == 5 and flags == 0 else "BirdQuietSettle"
				world.game._handle(action_packet(kind, serial))
				assert(actor.current_clip == (fitted if enhanced else classic))
				checks += 1
	if "--ettin" in OS.get_cmdline_user_args():
		for flags: int in [0, 0x40]:
			var serial := SERIAL + 18
			world.game._handle(mobile_packet(at, flags, serial, 18, 0x8035))
			var actor: Node3D = world.avatars[serial].horse_visual
			assert(actor.native_body == 18 and actor.native_hue == 0x8035)
			assert((actor.find_child("EnhancedHammer", true, false) != null) == enhanced)
			var prior: String = actor.current_clip
			world.game._handle(action_packet(15, serial))
			assert(actor.current_clip == ("EttinRise" if enhanced else prior))
			world.game._handle(action_packet(8, serial))
			assert(actor.current_clip == ("EttinAlert" if enhanced else "Pillage"))
			var death := PackedByteArray([0xaf])
			death.append_array(Wire.uint_be(serial, 4))
			death.append_array(Wire.uint_be(0, 4))
			death.append_array(Wire.uint_be(0, 4))
			world.game._handle(death)
			var visual: Node3D = world.creature_deaths.active[serial].visual
			assert(visual.current_clip == "Death" and visual.native_hue == 0x8035)
			assert((visual.find_child("EnhancedHammer", true, false) != null) == enhanced)
			world.creature_deaths.finish(serial)
			checks += 3
	if "--dolphin" in OS.get_cmdline_user_args():
		for flags: int in [0, 0x40]:
			var serial := SERIAL + 151
			world.game._handle(mobile_packet(at, flags, serial, 151, 0x8035))
			var actor: Node3D = world.avatars[serial].horse_visual
			assert(actor.native_body == 151 and actor.native_hue == 0x8035)
			assert(actor.entry.movement_mode == "native_waterline")
			assert(actor.animator.has_animation("DolphinBank") == enhanced)
			var prior: String = actor.current_clip
			for kind: int in [2, 5, 8, 14, 15, 11]:
				var classic := "Attack" if kind == 11 else prior
				var fitted := "DolphinBank" if kind == 5 and flags == 0 else "DolphinHover"
				world.game._handle(action_packet(kind, serial))
				assert(actor.current_clip == (fitted if enhanced and kind != 11 else classic))
				checks += 1
	if "--field" in OS.get_cmdline_user_args():
		checks += check_field(world, at, enhanced)
	if "--cat" in OS.get_cmdline_user_args():
		checks += check_cat(world, at, enhanced)
	print("WORLD CREATURE DISPATCH: ", checks, " checks, Enhanced profile ", enhanced)
	world.queue_free()
	await process_frame
	quit()

func check_field(world: Node, at: Vector2i, enhanced: bool) -> int:
	var checks := 0
	var hue := 0x8035
	for body: int in [205, 207, 223, 234, 237]:
		var serial := SERIAL + (207 if body == 223 else body)
		var previous: Node3D = world.avatars[serial].horse_visual if body == 223 else null
		var modes: Dictionary = Field.Profiles[body]
		for flags: int in [0, 0x40]:
			world.game._handle(mobile_packet(at, flags, serial, body, hue))
			var actor: Node3D = world.avatars[serial].horse_visual
			assert(actor != previous and actor.native_body == body and actor.native_hue == hue)
			checks += check_fitted_actions(world, actor, serial, modes, flags, enhanced)
		if body == 207:
			continue  # Keep this serial alive for the stock shearing body change.
		var death := PackedByteArray([0xaf])
		death.append_array(Wire.uint_be(serial, 4))
		death.append_array(Wire.uint_be(0, 4))
		death.append_array(Wire.uint_be(0, 4))
		world.game._handle(death)
		var visual: Node3D = world.creature_deaths.active[serial].visual
		assert(visual.current_clip == "Death" and visual.native_body == body and visual.native_hue == hue)
		world.creature_deaths.finish(serial)
		checks += 1
	return checks

func check_cat(world: Node, at: Vector2i, enhanced: bool) -> int:
	var serial := SERIAL + 201
	var checks := 0
	for flags: int in [0, 0x40]:
		world.game._handle(mobile_packet(at, flags, serial, 201, 0x647))
		var actor: Node3D = world.avatars[serial].horse_visual
		assert(actor.native_body == 201 and actor.native_hue == 0x647)
		assert(actor.animator.has_animation("CatSpring") == enhanced)
		checks += check_fitted_actions(world, actor, serial, Cats.CatModes, flags, enhanced)
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(PackedByteArray([0, 12, 0, 5, 0, 1, 0, 0, 0]))
	world.game._handle(packet)
	var hell_cat: Node3D = world.avatars[serial].horse_visual
	assert(hell_cat.current_clip == "Alert" and not hell_cat.dead)
	assert(hell_cat.get_meta("native_action") == world.game.last_mobile_actions[serial])
	return checks + 2

func check_fitted_actions(world: Node, actor: Node3D, serial: int, modes: Dictionary, flags: int, enhanced: bool) -> int:
	var checks := 0
	var mode: Dictionary = modes["0" if flags else "1"]
	var prior: String = actor.current_clip
	for kind: String in modes["0"]:
		var clips: Array = mode.get(kind, modes["0"][kind])
		for variation in [0, 1, 255]:
			world.game._handle(action_packet(int(kind), serial, variation))
			var expected: String = clips[variation % clips.size()] if enhanced and variation < 128 else prior
			assert(actor.current_clip == expected)
			prior = expected
			checks += 1
	return checks

func mobile_packet(at: Vector2i, flags: int, serial: int = SERIAL, body: int = BODY, hue: int = 1109) -> PackedByteArray:
	var bytes := PackedByteArray([0x77])
	bytes.append_array(Wire.uint_be(serial, 4))
	bytes.append_array(Wire.uint_be(body, 2))
	bytes.append_array(Wire.uint_be(at.x, 2))
	bytes.append_array(Wire.uint_be(at.y, 2))
	bytes.append_array(PackedByteArray([0, 0]))
	bytes.append_array(Wire.uint_be(hue, 2))
	bytes.append_array(PackedByteArray([flags, 1]))
	return bytes

func action_packet(kind: int, serial: int = SERIAL, variation: int = 1) -> PackedByteArray:
	var bytes := PackedByteArray([0xe2])
	bytes.append_array(Wire.uint_be(serial, 4))
	bytes.append_array(PackedByteArray([0, kind, 0, 0, variation]))
	return bytes
