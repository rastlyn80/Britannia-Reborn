# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Serpent := preload("res://Presentation/SourceEnhancedSeaSerpentVisual.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Body := 150


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
	var serial := 0x9150
	var native := mobile_packet(at, serial, Body, 0)
	native[13] = 0x08
	native[14] = 0xa2
	world.game._handle(native)
	var avatar: Node3D = world.avatars[serial]
	var actor: Node3D = avatar.horse_visual
	if not expect((actor is Serpent) == enhanced and actor.native_body == Body and actor.native_hue == 0x08a2,
			"the native deep serpent identity and hue select the intended presentation"):
		return
	if not expect(Registry.entry(145).get("presentation_script") != "res://Presentation/SourceEnhancedSeaSerpentVisual.gd",
			"the artwork sibling retains its own registered route"):
		return
	for test: Array in [[3, "Fidget"], [4, "Fidget2"], [5, "Attack"], [6, "Attack2"]]:
		world.game._handle(classic_packet(serial, test[0]))
		if not expect(actor.current_clip == test[1], "the Classic sea turn and strike remain in place"):
			return
	if enhanced:
		for flags: int in [0, 0x40]:
			actor.action_remaining = 0.
			world.game._handle(mobile_packet(at, serial, Body, flags))
			if flags != 0 and not expect(actor.current_clip == "SeaAlert", "war transition uses the distinct alert"):
				return
			actor.action_remaining = 0.
			for motion: Array in [[false, 0., "SeaCombatIdle" if flags != 0 else "SeaQuietIdle"],
					[true, 1.8, "SeaCombatSwim" if flags != 0 else "Walk"], [true, 5.4, "Run"]]:
				avatar.animate(motion[0], 0., .16, motion[1])
				if not expect(actor.current_clip == motion[2], "the normal client uses the appropriate swim or idle"):
					return
			for test: Array in [[0, 0, "SeaSnap"], [0, 1, "SeaDiveStrike"], [2, 0, "SeaGuard"], [4, 0, "SeaRecoil"],
					[5, 0, "SeaQuietFidget"], [5, 1, "SeaDeepFidget" if flags != 0 else "SeaQuietFidget"],
					[8, 0, "SeaAlert"], [11, 0, "SeaSnap"], [14, 0, "SeaQuietIdle"], [15, 0, "SeaQuietIdle"]]:
				world.game._handle(action_packet(serial, test[0], test[1]))
				if not expect(actor.current_clip == test[2], "the decoded Enhanced selector chooses the archive motion"):
					return
		for variant: int in [-1, 0, 1]:
			serial += 3
			if not await verify_fall(world, at, serial, variant, "Death2" if variant == 1 else "Death", Body):
				return
	print("SEA SERPENT WORLD: ", checks, " checks, Enhanced ", enhanced)
	quit()
