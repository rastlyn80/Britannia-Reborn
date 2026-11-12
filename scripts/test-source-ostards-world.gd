# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const SourceOstard := preload("res://Presentation/SourceEnhancedOstard.gd")
const Cadavers := preload("res://Presentation/CorpseModels.gd")


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var enabled := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	var serial := 0x5301
	for body: int in SourceOstard.Forms:
		var item: int = SourceOstard.Forms[body].item
		world.game._handle(mobile_packet(at, serial, body, 0))
		var avatar: Node3D = world.avatars[serial]
		var actor: Node3D = avatar.horse_visual
		if not expect((actor is SourceOstard) == enabled and actor.native_body == body
				and actor.kind == SourceOstard.Forms[body].kind, "native appearance selects the correct body and profile"):
			return
		if not expect(Cadavers.catalogue().any(func(row: Dictionary):
				return row.body == body and row.graphic == 0x2006), "static graphic catalogue includes this body"):
			return
		for stage in 3:
			avatar.animate(stage > 0, 0.0, .1, [0.0, 1.8, 5.5][stage])
			var gait: String = SourceOstard.Gaits[1][stage] if enabled else ["Idle", "Walk", "Run"][stage]
			if not expect(actor.current_clip == gait, "loose gait uses the correct current profile"):
				return
		if enabled:
			world.game._handle(mobile_packet(at, serial, body, 0x40))
			avatar.animate(false, 0.0, .1, 0.0)
			if not expect(actor.current_clip == "OstardCombatReady", "the server combat flag triggers the official transition"):
				return
			for variant in 6:
				for test: Array in [
					[0, 0, 5 if variant % 3 == 1 else 4], [0, 9, 4], [0, 255, 5 if variant == 1 else 4],
					[2, 0, 15], [4, 0, 10], [5, 0, 27 if variant % 2 else 26], [8, 0, 28],
					[11, 0, 4], [14, 0, 25], [15, 0, 23],
				]:
					var packet := action_packet(serial, test[0], variant)
					packet[8] = test[1]
					world.game._handle(packet)
					if not expect(actor.current_clip == SourceOstard.Groups[test[2]], "normal packet dispatch selects the registered gesture"):
						return
		for gender: int in [400, 401]:
			serial += 1
			world.game._handle(mobile_packet(at, serial, gender, 0))
			world.game._handle(wear_packet(serial, item, CorpseHue))
			var rider: Node3D = world.avatars[serial]
			var ridden: Node3D = rider.horse_visual
			if not expect((ridden is SourceOstard) == enabled and ridden.native_body == body
					and ridden.native_mount_item == item and ridden.native_hue == CorpseHue, "stock worn graphic selects the dyed mount"):
				return
			for stage in 3:
				rider.animate(stage > 0, 0.0, .1, [0.0, 1.8, 5.5][stage])
				var gait: String = SourceOstard.Gaits[2][stage] if enabled else ["Idle", "Walk", "Run"][stage]
				if not expect(ridden.current_clip == gait, "male and female rider use the matching seated animation"):
					return
		if enabled:
			for sample: Array in [[-1, "Death"], [0, "Death"], [1, "Death2"], [12, "Death2" if body == 210 and actor.desert_actions != null else "Death"]]:
				serial += 8
				if not await verify_fall(world, at, serial, sample[0], sample[1], body):
					return
		serial += 8
	print("SOURCE OSTARDS WORLD: ", checks, " checks; Enhanced ", enabled, ", two native bodies")
	quit()
