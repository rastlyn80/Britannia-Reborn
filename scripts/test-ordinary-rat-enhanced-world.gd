# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Rat := preload("res://Presentation/SourceEnhancedOrdinaryRatVisual.gd")
const Body := 238


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
	var serial := 0x2380
	var packet := mobile_packet(at, serial, Body, 0)
	packet[13] = CorpseHue >> 8
	packet[14] = CorpseHue & 0xff
	world.game._handle(packet)
	var avatar: Node3D = world.avatars[serial]
	var actor: Node3D = avatar.horse_visual
	if not expect((actor is Rat) == enhanced and actor.native_body == Body and actor.native_hue == CorpseHue
			and actor.kind == "rat_ordinary" and actor.skeleton.get_bone_count() == 21
			and actor.contact.feet.size() == 4, "native ordinary Rat retains its public rig and four ground contacts"):
		return
	for sample: Array in [[0, "Walk"], [1, "Run"], [2, "Idle"], [3, "Eat"], [4, "Alert"], [5, "Attack"],
			[6, "Attack2"], [7, "Hit"], [9, "RatRear"], [10, "Fidget2"]]:
		world.game._handle(classic_packet(serial, sample[0]))
		if not expect(actor.current_clip == sample[1], "the Classic rat route keeps its own clip"):
			return
	if enhanced:
		for flags: int in [0, 0x40]:
			world.game._handle(mobile_packet(at, serial, Body, flags))
			for variation: int in [0, 1, 2, 7, 127]:
				for sample: Array in [[2, "RatNoseRecoil"], [5, "RatTailSweep" if flags and variation % 2 else "RatScentCheck"],
						[8, "RatNoseAlert"], [11, "RatForwardBite"], [14, "RatForage"], [15, "RatTailUnfurl"]]:
					world.game._handle(action_packet(serial, sample[0], variation))
					if not expect(actor.current_clip == sample[1], "the decoded variant selects the body-215 linked motion"):
						return
		world.game._handle(action_packet(serial, 5, 0))
		avatar.animate(true, 0., .16, 5.5)
		if not expect(actor.current_clip == "Run", "an idle gesture does not delay native movement"):
			return
		world.game._handle(action_packet(serial, 11, 0))
		avatar.animate(true, 0., .16, 1.8)
		if not expect(actor.current_clip == "RatForwardBite", "the attack follows its action duration"):
			return
		for info: Array in [[-1, "Death"], [0, "Death"], [12, "Death2"]]:
			serial += 4
			if not await verify_fall(world, at, serial, info[0], info[1], Body):
				return
		for type: int in [2, 5, 8, 11, 14, 15]:
			serial += 4
			if not await verify_interrupted(world, at, serial, type):
				return
	print("ORDINARY RAT WORLD: ", checks, " checks, Enhanced ", enhanced)
	quit()


func verify_interrupted(world: Node3D, at: Vector2i, serial: int, type: int) -> bool:
	world.game._handle(mobile_packet(at, serial, Body, 0x40))
	world.game._handle(action_packet(serial, type, 0))
	var actor: Node3D = world.avatars[serial].horse_visual
	actor.animator.advance(.12)
	actor.animator.seek(.37 * actor.animator.current_animation_length, true)
	actor.contact.modification_processed.emit()
	var prior := joint_positions(actor)
	var corpse := 0x40003000 + serial
	if type % 2 == 0:
		world.game._handle(corpse_packet(at, corpse, Body, 0))
	world.game._handle(death_packet(serial, corpse))
	if type % 2 != 0:
		world.game._handle(corpse_packet(at, corpse, Body, 0))
	var transition: Dictionary = world.creature_deaths.active.get(serial, {})
	if not expect(not transition.is_empty(), "native death starts the transition"):
		return false
	var posed: Node3D = transition.visual
	var next := joint_positions(posed)
	var displacement := 0.0
	for joint in prior.size():
		displacement = maxf(displacement, prior[joint].distance_to(next[joint]))
	if not expect(displacement < .003, "the fall preserves the displayed small rig, delta %.5f m" % displacement):
		return false
	var item: Node3D = world.world_items.nodes[corpse]
	await create_timer(float(transition.remaining) + .12).timeout
	var cadaver: Node3D = item.get_node("CorpseVisual")
	var before := cadaver.global_transform
	var bounds: AABB = cadaver.get_meta("corpse_bounds")
	world.game._handle(corpse_packet(at, corpse, Body, CorpseHue))
	item = world.world_items.nodes[corpse]
	cadaver = item.get_node("CorpseVisual")
	return expect(item.visible and cadaver.get_meta("corpse_body") == Body and cadaver.get_meta("native_hue") == CorpseHue
		and cadaver.get_meta("death_clip") == "Death" and cadaver.get_meta("corpse_bounds") == bounds
		and cadaver.global_transform.is_equal_approx(before) and cadaver.find_children("*", "Skeleton3D").is_empty(),
		"the native cadaver retains pose, bounds and late partial dye")
