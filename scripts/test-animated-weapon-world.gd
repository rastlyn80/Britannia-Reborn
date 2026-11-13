# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-ordinary-horse-world.gd"

const Body := 692
const Collapse := "EnhancedHalberdCollapse"
const Living := {0: "EnhancedHalberdSweep", 2: "EnhancedHalberdRecoil", 4: "EnhancedHalberdRecoil",
	8: "EnhancedHalberdSpin", 11: "UopHalberdHover", 14: "UopHalberdHover", 15: "EnhancedHalberdRise"}
const Classic := {2: "Death", 4: "Attack", 10: "Hit", 17: "Fidget"}


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
	for flags: int in [0, 64]:
		for parity in 2:
			var serial := 0x370000 + flags + parity
			world.game._handle(mobile_packet(at, serial, Body, flags))
			var actor: Node3D = world.avatars[serial].horse_visual
			if not expect(actor != null and actor.native_body == Body, "Animated Weapon uses its registered model"):
				return
			for group: int in [4, 10, 17]:
				world.game._handle(classic_packet(serial, group))
				if not expect(actor.current_clip == Classic[group] and not actor.dead, "Classic actions retain their keys"):
					return
			if enhanced:
				for variation in 128:
					for kind: int in Living:
						world.game._handle(action_packet(serial, kind, variation))
						if not expect(actor.current_clip == Living[kind] and not actor.dead and
								actor.get_meta("native_action").variation == variation,
								"Enhanced body %d action %d variation %d selected %s" % [Body, kind, variation, actor.current_clip]):
							return
						if kind == 0:
							for subaction: int in [1, 2, 9, 255, 0x101]:
								var attack := action_packet(serial, kind, variation)
								attack[7] = subaction >> 8
								attack[8] = subaction & 255
								world.game._handle(attack)
								if not expect(actor.current_clip == Living[0] and actor.get_meta("native_action").subaction == subaction,
										"All exact and wildcard source attacks use the sweep"):
									return
					world.game._handle(action_packet(serial, 5, variation))
					var hover := "UopHalberdReadyHover" if flags == 0 else "UopHalberdHover"
					if not expect(actor.current_clip == hover and not actor.dead, "Enhanced hover uses the actor's stance"):
						return
				world.game._handle(action_packet(serial, 3, parity))
			else:
				world.game._handle(classic_packet(serial, 2))
			var death_clip := Collapse if enhanced else "Death"
			if not expect(actor.current_clip == death_clip and actor.dead, "Both source variants select the weapon's fall"):
				return
			world.game._handle(death_packet(serial, 0))
			var state: Dictionary = world.creature_deaths.active.get(serial, {})
			if not expect(not state.is_empty() and state.visual.current_clip == death_clip and state.corpse == 0,
					"The temporary collapse preserves native corpse suppression"):
				return
			await create_timer(float(state.remaining) + .12).timeout
			if not expect(not is_instance_valid(state.visual), "Transient death releases its rendering node"):
				return
	print("ANIMATED WEAPON WORLD: ", checks, " checks, Enhanced ", enhanced)
	quit(0)


func classic_packet(serial: int, group: int) -> PackedByteArray:
	var wire := PackedByteArray([0x6e])
	wire.append_array(Wire.uint_be(serial, 4))
	wire.append_array(PackedByteArray([0, group, 0, 8, 0, 1, 1, 0, 0]))
	return wire
