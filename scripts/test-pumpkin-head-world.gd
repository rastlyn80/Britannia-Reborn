# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-ordinary-horse-world.gd"

const Lunge := "EnhancedPumpkinLunge"
const Dormant := "EnhancedPumpkinDormant"
const Collapse := "EnhancedPumpkinCollapse"
const Ignition := "EnhancedPumpkinIgnition"
const Living := {0: Lunge, 2: "EnhancedPumpkinSway", 4: "EnhancedPumpkinRecoil",
	8: Ignition, 14: Dormant, 15: Dormant}


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	if not expect(world.enhanced_creature_actions == enhanced, "Requested client mode starts"):
		return
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	for body: int in [1246, 1247]:
		for flags: int in [0, 64]:
			var serial := 0x370000 + body * 2 + flags
			world.game._handle(mobile_packet(at, serial, body, flags))
			var actor: Node3D = world.avatars[serial].horse_visual
			if not expect(actor != null and actor.native_body == body, "Pumpkin Head uses the registered model"):
				return
			for group: int in [4, 10, 25, 28]:
				world.game._handle(classic_packet(serial, group))
				if not expect(actor.current_clip == actor.entry.classic_action_categories[str(group)] and not actor.dead,
						"Classic actions retain their existing motion"):
					return
			if enhanced:
				var fixed: Dictionary = Living.merged({11: Lunge if body == 1246 else "EnhancedPumpkinPlume"})
				for variation in 128:
					for kind: int in fixed:
						world.game._handle(action_packet(serial, kind, variation))
						if not expect(actor.current_clip == fixed[kind] and not actor.dead,
								"Enhanced body %d type %d chose %s" % [body, kind, actor.current_clip]):
							return
					world.game._handle(action_packet(serial, 5, variation))
					var selected := "Idle" if flags else ("DormantShuffle" if body == 1246 else Dormant)
					if not expect(actor.current_clip == selected and not actor.dead, "Pumpkin fidget follows actor mode"):
						return
				world.game._handle(action_packet(serial, 3, 127))
			else:
				world.game._handle(classic_packet(serial, 2))
			var death_clip := Collapse if enhanced else "Death"
			if not expect(actor.current_clip == death_clip and actor.dead, "Packet selects its collapse"):
				return
			var corpse := 0x40000000 + serial
			world.game._handle(corpse_packet(at, corpse, body, CorpseHue))
			world.game._handle(death_packet(serial, corpse))
			var state: Dictionary = world.creature_deaths.active.get(serial, {})
			if not expect(not state.is_empty() and state.visual.current_clip == death_clip, "Death keeps the chosen fall"):
				return
			await create_timer(float(state.remaining) + .18).timeout
			var frozen: Node3D = world.world_items.nodes[corpse].get_node_or_null("CorpseVisual")
			if not expect(frozen != null and frozen.get_meta("corpse_body") == body and
					frozen.get_meta("native_hue") == CorpseHue and frozen.get_meta("death_clip") == death_clip
					and frozen.find_children("*", "Skeleton3D", true, false).is_empty(), "Corpse is static and dyed"):
				return
			for mesh: MeshInstance3D in frozen.find_children("*", "MeshInstance3D", true, false):
				if not expect(not str(mesh.name).begins_with("Flame") and not str(mesh.name).begins_with("Jaw"),
						"Only the gourd remains after death"):
					return
	print("PUMPKIN HEAD ENHANCED WORLD: ", checks, " checks, Enhanced ", enhanced)
	quit(0)


func classic_packet(serial: int, group: int) -> PackedByteArray:
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(PackedByteArray([0, group, 0, 8, 0, 1, 1, 0, 0]))
	return packet
