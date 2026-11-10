# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Wire := preload("res://Network/LoginProtocol.gd")
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
	print("WORLD CREATURE DISPATCH: ", checks, " checks, Enhanced profile ", enhanced)
	world.queue_free()
	await process_frame
	quit()

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

func action_packet(kind: int, serial: int = SERIAL) -> PackedByteArray:
	var bytes := PackedByteArray([0xe2])
	bytes.append_array(Wire.uint_be(serial, 4))
	bytes.append_array(PackedByteArray([0, kind, 0, 0, 1]))
	return bytes
