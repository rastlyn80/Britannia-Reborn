# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Serpent := preload("res://Presentation/SourceEnhancedSilverSerpentVisual.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Body := 92


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	var serial := 0x9121
	var packet := mobile_packet(at, serial, Body, 0)
	packet[13] = CorpseHue >> 8
	packet[14] = CorpseHue & 0xff
	world.game._handle(packet)
	var avatar: Node3D = world.avatars[serial]
	var actor: Node3D = avatar.horse_visual
	if not expect((actor is Serpent) == enhanced and actor.native_body == Body and actor.native_hue == CorpseHue,
			"native silver serpent identity and hue select the intended presentation"):
		return
	if not expect(Registry.entry(91).get("presentation_script") == "res://Presentation/SourceSilverSerpentVisual.gd",
			"the compatibility sibling keeps its existing source visual"):
		return
	for test: Array in [[4, "Attack"], [5, "Attack"], [6, "Attack"], [10, "Hit"], [11, "Pillage"],
			[15, "Hit"], [16, "Hit"], [17, "Fidget"], [18, "Fidget"]]:
		world.game._handle(classic_packet(serial, test[0]))
		if not expect(actor.current_clip == test[1], "the Classic action still uses its established motion"):
			return
	if enhanced:
		for flags: int in [0, 0x40]:
			actor.action_remaining = 0.
			world.game._handle(mobile_packet(at, serial, Body, flags))
			if flags != 0 and not expect(actor.current_clip == "SerpentCoilAlert", "war transition uses the gather"):
				return
			actor.action_remaining = 0.
			for motion: Array in [[false, 0., "Idle" if flags else "SerpentQuietIdle"],
					[true, 1.8, "SerpentCombatSlither" if flags else "Walk"], [true, 5.4, "Run"]]:
				avatar.animate(motion[0], 0., .16, motion[1])
				if not expect(actor.current_clip == motion[2], "the decoded combat state selects the correct slither"):
					return
			for variation: int in [0, 1, 2, 7, 127]:
				for sample: Array in [[0, "SerpentUncoilStrike"], [2, "LowNeckRecoil"], [4, "Hit"],
						[5, "SerpentRaisedCoil" if flags and variation % 2 else "SerpentLowWatch"],
						[8, "SerpentCoilAlert"], [11, "SerpentUncoilStrike"], [14, "Pillage"], [15, "SerpentSurface"]]:
					world.game._handle(action_packet(serial, sample[0], variation))
					if not expect(actor.current_clip == sample[1], "the wire selector plays its registered archive motion"):
						return
		world.game._handle(classic_packet(serial, 17))
		avatar.animate(true, 0., .16, 5.4)
		if not expect(actor.current_clip == "Run", "native movement interrupts a standing fidget"):
			return
		world.game._handle(action_packet(serial, 0, 0))
		avatar.animate(true, 0., .16, 1.8)
		if not expect(actor.current_clip == "SerpentUncoilStrike", "the active strike plays through movement"):
			return
		for variant: int in [-1, 0, 1]:
			serial += 3
			if not await verify_fall(world, at, serial, variant, "Death2" if variant == 0 else "Death", Body):
				return
	for action: int in [2, 3]:
		serial += 3
		world.game._handle(mobile_packet(at, serial, Body, 0))
		world.game._handle(classic_packet(serial, action))
		var victim: Node3D = world.avatars[serial].horse_visual
		if not expect(victim.current_clip == "Death", "Classic death retains the established fall"):
			return
	print("SILVER SERPENT WORLD: ", checks, " checks, Enhanced ", enhanced)
	quit()
