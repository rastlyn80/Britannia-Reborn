# SPDX-License-Identifier: GPL-3.0-or-later
extends "test-ordinary-horse-world.gd"

const Cattle := preload("res://Presentation/SourceEnhancedBovineVisual.gd")
const Baseline := preload("res://Presentation/BovineActionsVisual.gd")
const Common := {2: [15, 15], 4: [10], 8: [28], 11: [1, 25, 25], 14: [25], 15: [25]}
var reports := {}


func run() -> void:
	var scene := load("res://Main.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	if not verify(Mounts.Animals.enhanced_bovine_actions == enhanced, "cattle mode follows the world option"):
		return
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	for body: int in Cattle.Bodies:
		if not await check_cattle(world, at, body, enhanced):
			return
	if enhanced and not verify(reports[232].height > reports[233].height + .05, "bull back roll and side fall have different frozen heights"):
		return
	print("CATTLE WORLD: ", checks, " checks, Enhanced ", enhanced, "; ", reports)
	quit()


func check_cattle(world: Node3D, at: Vector2i, body: int, enhanced: bool) -> bool:
	var serial := 0x3150 + body
	var corpse := 0x40000000 + serial
	world.game._handle(mobile_packet(at, serial, body, 0))
	world.avatars[serial].rotation.y = PI
	var actor: Node3D = world.avatars[serial].horse_visual
	if not verify(actor is Baseline and (actor is Cattle) == enhanced and actor.native_body == body, "correct cattle visual and identity"):
		return false
	actor.play_gait(false, 0.)
	if not verify(actor.current_clip == (Cattle.Grazing if enhanced else "Idle"), "quiet standing mode"):
		return false
	if body in [216, 231]:
		world.game._handle(classic_packet(serial, 8, 0, 3))
		if not verify(actor.recovering_tip and not actor.dead and actor.current_clip == "LieDown", "native cow-tip is living rest"):
			return false
		actor._process(actor.action_remaining + .01)
		if not verify(not actor.dead and not actor.recovering_tip and actor.current_clip == (Cattle.Grazing if enhanced else "Idle"),
				"cow returns to living standing mode"):
			return false
	if enhanced:
		world.game._handle(mobile_packet(at, serial, body, 0x40))
		if not verify(actor.current_clip == Cattle.Alert, "peace to combat raises the head"):
			return false
		actor.action_remaining = 0.
		actor.play_gait(true, 2.)
		if not verify(actor.current_clip == "Walk", "walk uses retained source gait"):
			return false
		actor.play_gait(true, 6.)
		if not verify(actor.current_clip == "Run", "run uses retained source gait"):
			return false
		for flags in [0, 0x40]:
			world.game._handle(mobile_packet(at, serial, body, flags))
			for variant in [0, 1, 2, 127]:
				for type: int in Common:
					var options: Array = Common[type]
					if not select(world, actor, serial, type, variant, int(options[variant % options.size()])):
						return false
				var fidget := 25 if flags != 0 and (variant % 2) == 1 else 26
				if not select(world, actor, serial, 5, variant, fidget):
					return false
				for subaction in [0, 1, 2, 9, 255]:
					var option := 1
					if subaction == 0 and variant % 3 == 0 or subaction == 255 and variant % 6 == 0:
						option = 25
					if not select(world, actor, serial, 0, variant, option, subaction):
						return false
		if body in [232, 233]:
			if not select(world, actor, serial, 3, 1, 1) or not verify(not actor.dead, "bull's standing alternate waits for the actual death"):
				return false
		else:
			if not select(world, actor, serial, 3, 1, 2) or not verify(actor.dead, "cow's alternate still selects its fitted fall"):
				return false
	else:
		world.game._handle(classic_packet(serial, 12, 6, 1))
		if not verify(actor.current_clip == "Death2" and actor.dead, "Classic second fall remains routed"):
			return false
	actor.animator.advance(0.)
	actor.animator.seek(actor.animator.current_animation_length * .31, true)
	var before := head(actor)
	world.game._handle(corpse_packet(at, corpse, body, 0))
	world.game._handle(death_packet(serial, corpse))
	var state: Dictionary = world.creature_deaths.active.get(serial, {})
	var holder: Node3D = world.world_items.nodes[corpse]
	var clip := Cattle.FittedFall if enhanced else "Death2"
	if not verify(not state.is_empty() and not holder.visible and state.visual.current_clip == clip,
			"correct live visual enters native death transition"):
		return false
	var jump := before.distance_to(head(state.visual))
	if not verify(jump < .0025, "death handoff preserves the displayed head"):
		return false
	await create_timer(float(state.remaining) + .18).timeout
	var frozen: Node3D = holder.get_node("CorpseVisual")
	if not verify(holder.visible and frozen.get_meta("death_clip") == clip and frozen.find_children("*", "Skeleton3D", true, false).is_empty(),
			"static cadaver retains the live death pose"):
		return false
	var position := frozen.global_transform
	var bounds: AABB = frozen.get_meta("corpse_bounds")
	world.game._handle(corpse_packet(at, corpse, body, CorpseHue))
	var dyed: Node3D = world.world_items.nodes[corpse].get_node("CorpseVisual")
	if not verify(dyed.get_meta("native_hue") == CorpseHue and dyed.get_meta("death_clip") == clip
			and dyed.global_transform.is_equal_approx(position) and dyed.get_meta("corpse_bounds") == bounds,
			"late native dye retains static geometry and position"):
		return false
	reports[body] = {"height": bounds.size.y, "head_handoff_m": jump, "clip": clip}
	return true


func select(world: Node3D, actor: Node3D, serial: int, type: int, variant: int, group: int, subaction: int = 0) -> bool:
	var packet := action_packet(serial, type, variant)
	packet[8] = subaction
	world.game._handle(packet)
	return verify(actor.get_meta("enhanced_bovine_group", -1) == group and actor.current_clip == Cattle.Clips[group],
		"mode, body and variation select fitted cattle group %d (type %d)" % [group, type])


func classic_packet(serial: int, group: int, frames: int, repeat: int) -> PackedByteArray:
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(Wire.uint_be(group, 2))
	packet.append_array(Wire.uint_be(frames, 2))
	packet.append_array(Wire.uint_be(repeat, 2))
	packet.append_array(PackedByteArray([1, 0, 0]))
	return packet


func head(actor: Node3D) -> Vector3:
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 head")).origin)


func verify(value: bool, message: String) -> bool:
	checks += 1
	if not value:
		printerr("CATTLE WORLD FAIL: ", message)
		quit(1)
	return value
