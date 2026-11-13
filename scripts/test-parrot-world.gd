# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-ordinary-horse-world.gd"

const Bird := 831
const Rest := "ParrotRestingCrouch"
const Recoil := "ParrotRaisedWingRecoil"
const Fall := "ParrotFallingTuck"
const Tuck := "UopParrotWingTuck"
const Results := {0: Rest, 2: Rest, 4: Recoil, 8: Rest, 11: Rest, 14: Rest, 15: Rest}


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var enhanced: bool = world.enhanced_creature_actions
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	for flags: int in [0, 64, 4]:
		var serial := 0x370000 + flags
		world.game._handle(mobile_packet(at, serial, Bird, flags))
		var actor: Node3D = world.avatars[serial].horse_visual
		if not expect(actor != null and actor.native_body == Bird, "Parrot uses its registered body"):
			return
		if not enhanced:
			var classic := PackedByteArray([0x6e])
			classic.append_array(Wire.uint_be(serial, 4))
			classic.append_array(PackedByteArray([0, 19, 0, 8, 0, 1, 1, 0, 0]))
			world.game._handle(classic)
			if not expect(actor.current_clip == "Fly" and not actor.dead, "Classic flight still plays"):
				return
			continue
		for variation in range(128):
			for kind: int in Results:
				world.game._handle(action_packet(serial, kind, variation))
				if not expect(actor.current_clip == Results[kind] and not actor.dead,
						"Parrot %d flags %d variant %d selected %s" % [kind, flags, variation, actor.current_clip]):
					return
			world.game._handle(action_packet(serial, 5, variation))
			if not expect(actor.current_clip == (Rest if flags != 0 and variation % 2 else Tuck),
					"Body 831 chooses the source fidget for its actor mode"):
				return
		world.game._handle(action_packet(serial, 3, 127))
		if not expect(actor.current_clip == Rest, "The second type-3 choice is the source resting crouch"):
			return
		world.game._handle(action_packet(serial, 3, 126))
		if not expect(actor.current_clip == Fall and actor.dead, "The first type-3 choice starts the tuck and fall"):
			return
		var corpse := 0x40000000 + serial
		world.game._handle(corpse_packet(at, corpse, Bird, CorpseHue))
		world.game._handle(death_packet(serial, corpse))
		var state: Dictionary = world.creature_deaths.active.get(serial, {})
		if not expect(not state.is_empty() and state.visual.current_clip == Fall, "Corpse continues the selected cast-down pose"):
			return
		await create_timer(float(state.remaining) + .18).timeout
		var holder: Node3D = world.world_items.nodes.get(corpse)
		var frozen := holder.get_node_or_null("CorpseVisual")
		if not expect(frozen != null and frozen.get_meta("corpse_body") == Bird and frozen.get_meta("native_hue") == CorpseHue
				and frozen.get_meta("death_clip") == Fall and frozen.find_children("*", "Skeleton3D", true, false).is_empty(),
				"Dyed Parrot corpse freezes the fitted pose"):
			return
	print("PARROT VARIANTS WORLD: ", checks, " checks, Enhanced ", enhanced)
	quit(0)
