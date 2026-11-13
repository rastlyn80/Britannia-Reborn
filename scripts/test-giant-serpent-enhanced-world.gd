# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Serpent := preload("res://Presentation/SourceTerrainGiantSerpentVisual.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Body := 21


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
	if not expect(actor is Serpent and actor.fitted_actions == enhanced and actor.native_body == Body and actor.native_hue == CorpseHue,
			"native giant serpent identity and hue select the intended presentation"):
		return
	var silver := Registry.entry(92)
	var silver_asset := Registry.asset_path(silver)
	if not expect(silver.get("kind") == "serpents_snake_giant_silver"
			and Registry.supports_body(92) and silver_asset != Registry.asset_path(Registry.entry(Body)),
			"the silver serpent keeps its own verified scene in the active profile"):
		return
	for test: Array in [[4, "CoilSnap"], [5, "Attack"], [6, "LongStrike"], [10, "Hit"], [11, "Pillage"],
			[15, "NeckDrawback"], [16, "LowNeckRecoil"], [17, "Fidget"], [18, "TailRipple"]]:
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
		actor.action_remaining = 0.0
		avatar.animate(false, 0., .16, 0.)
		world.game._handle(classic_packet(serial, 17))
		if not expect(actor.current_clip == "Fidget", "a standing serpent plays the Classic fidget"):
			return
		avatar.animate(true, 0., .16, 5.4)
		if not expect(actor.current_clip == "Run", "native movement interrupts a standing fidget"):
			return
		world.game._handle(classic_packet(serial, 17))
		if not expect(actor.current_clip == "Run", "a Classic fidget does not replace the running slither"):
			return
		world.game._handle(action_packet(serial, 0, 0))
		avatar.animate(true, 0., .16, 1.8)
		if not expect(actor.current_clip == "SerpentUncoilStrike", "the active strike plays through movement"):
			return
		for variant: int in [-1, 0, 1]:
			serial += 3
			if not await verify_fall(world, at, serial, variant, "Death2" if variant == 0 else "Death", Body):
				return
	print("GIANT SERPENT WORLD: ", checks, " checks, Enhanced ", enhanced)
	quit()
