# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Archer := preload("res://Presentation/SourceRatmanArcherVisual.gd")
const Projectiles := preload("res://Presentation/RatmanArrowPresenter.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Body := 142
const BodyHue := 0x0901
const BowHue := 0x0481
const Arrow := 0x0f42


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var effects: Projectiles
	for child: Node in world.get_children():
		if child is Projectiles:
			effects = child
			break
	var common := "res://Presentation/SourceLivingRatmanVisual.gd" if "--ratman-terrain" in OS.get_cmdline_user_args() else ""
	if not expect(effects != null and Registry.entry(44).get("presentation_script", "") == common
			and Registry.entry(45).get("presentation_script", "") == common, "only the native Archer entry has the bow renderer"):
		return
	var at := Vector2i(int(world.world.originX) + 12, int(world.world.originY) + 12)
	var serial := 0x6b00
	var target_serial := serial + 1
	var target_at := at + Vector2i(0, -6)
	world.game._handle(mobile_packet(target_at, target_serial, 400, 0))
	world.game._handle(mobile_packet(at, serial, Body, 0x40))
	var avatar: Node3D = world.avatars[serial]
	avatar.rotation.y = world.directions[serial]
	var archer := avatar.horse_visual as Archer
	if not expect(archer != null and archer.native_body == Body and archer.skeleton.get_bone_count() == 45
			and archer.bow == null, "native Archer has the original rig and no invented equipment"):
		return
	var item := wear_packet(serial, 0x13b2, BowHue)
	item[8] = 2
	world.game._handle(item)
	if not expect(archer.bow_release_available() and archer.bow_hue == BowHue
			and Archer.rest_bow.surface_get_array_index_len(0) == 276
			and Archer.string_vertices.size() >= 3, "native layer 2 equips the original 92-triangle bow and its own hue"):
		return
	var bow_material := archer.bow.get_active_material(0)
	var dyed := mobile_packet(at, serial, Body, 0x40)
	dyed[13] = BodyHue >> 8
	dyed[14] = BodyHue & 0xff
	world.game._handle(dyed)
	if not expect(archer.native_hue == BodyHue and archer.bow.get_active_material(0) == bow_material,
			"mobile hue leaves the worn bow's independent hue intact"):
		return
	for gait: String in ["Idle", "Walk", "Run"]:
		for yaw: float in [-.55, 0.0, .55]:
			avatar.set_process(false)
			avatar.set_physics_process(false)
			archer.play(gait, 0.0)
			archer.animator.advance(0.0)
			archer.rotate_y(yaw)
			if not await check_shot(world, effects, archer, serial, target_serial, at, target_at, gait):
				return
			archer.rotate_y(-yaw)
	var alternate_item := wear_packet(serial, 0x13b1, BowHue)
	alternate_item[8] = 2
	world.game._handle(alternate_item)
	if not expect(archer.bow_release_available() and archer.bow_hue == BowHue, "flipped native Bow art still equips"):
		return
	replay_effect(world, arrow_packet(serial, target_serial, at, target_at, 0xc7))
	var corpse := 0x4001ab00
	world.game._handle(corpse_packet(at, corpse, Body, BodyHue))
	world.game._handle(death_packet(serial, corpse))
	var transition: Dictionary = world.creature_deaths.active.get(serial, {})
	if not expect(not transition.is_empty() and transition.visual.bow.visible
			and transition.visual.bow_hue == BowHue, "native corpse sequence retains the visible worn bow"):
		return
	await create_timer(.15).timeout
	if not expect(effects.has_node("NativeRatmanArrow"), "the native arrow survives death during release"):
		return
	await create_timer(float(transition.remaining) + .15).timeout
	var item_node: Node3D = world.world_items.nodes[corpse]
	var frozen := item_node.get_node_or_null("CorpseVisual") as Node3D
	if not expect(frozen != null and item_node.visible and frozen.has_node("RatmanBow")
			and frozen.find_children("*", "Skeleton3D").is_empty(), "the static corpse includes the frozen bow"):
		return
	var placement := frozen.global_transform
	var frozen_bow := frozen.get_node("RatmanBow") as MeshInstance3D
	var frozen_material := frozen_bow.get_active_material(0)
	world.game._handle(corpse_packet(at, corpse, Body, CorpseHue))
	frozen = world.world_items.nodes[corpse].get_node("CorpseVisual")
	frozen_bow = frozen.get_node_or_null("RatmanBow")
	if not expect(frozen_bow != null and frozen_bow.get_active_material(0) == frozen_material
			and frozen.global_transform.is_equal_approx(placement)
			and frozen.get_meta("native_hue") == CorpseHue, "late corpse dye keeps the static bow and its dye"):
		return
	print("RATMAN ARCHER WORLD: ", checks, " checks, Enhanced ", world.enhanced_creature_actions)
	world.queue_free()
	await process_frame
	quit()


func check_shot(world: Node3D, effects: Projectiles, archer: Archer, source: int, target: int, at: Vector2i,
		target_at: Vector2i, gait: String) -> bool:
	var transform := archer.global_transform
	var nocks: Array[Vector3] = []
	var errors: Array[float] = []
	var sample := func():
		if archer.aim.elapsed < .075 or archer.aim.elapsed > .14:
			return
		var grip_error := archer.bow.to_global(Archer.Grip).distance_to(archer.grasp(archer.left_grasp))
		var string_point := archer.bow.to_global(Archer.string_center + archer.draw_offset)
		var draw_error := string_point.distance_to(archer.grasp(archer.right_grasp))
		nocks.append(archer.bow_arrow_origin())
		errors.append(grip_error if archer.aim.elapsed > .12 else maxf(grip_error, draw_error))
		if "--ratman-probe" in OS.get_cmdline_user_args():
			print("draw fit ", [archer.aim.elapsed, grip_error, draw_error, archer.draw_offset, string_point, archer.grasp(archer.right_grasp)])
	archer.aim.modification_processed.connect(sample)
	replay_effect(world, arrow_packet(source, target, at, target_at))
	await create_timer(.145).timeout
	archer.aim.modification_processed.disconnect(sample)
	var arrow := effects.get_node_or_null("NativeRatmanArrow") as Node3D
	if not expect(arrow != null and nocks.size() >= 3 and nocks.all(func(point: Vector3): return point.is_finite())
			and archer.global_transform == transform and archer.animator.assigned_animation == gait,
			"decoded arrow launches while the original gait and world transform continue: %s" %
			str([arrow != null, nocks.size(), archer.aim.elapsed, archer.animator.assigned_animation])):
		return false
	var max_error := float(errors.max())
	if not expect(max_error <= .025, "wrist-to-grip and right-hand string errors remain within tolerance: %.4f" % max_error):
		return false
	var aim_at: Vector3 = world.avatars[target].global_position + Vector3.UP * 1.2
	var path: Vector3 = (aim_at - nocks[-1]).normalized()
	if not expect(arrow.global_basis.z.dot(path) < -.99
			and (arrow.global_position - nocks[-1]).cross(path).length() < .12, "arrow flies from the bow toward the native target"):
		return false
	await create_timer(.52).timeout
	return expect(archer.aim.elapsed >= Archer.BowAim.RecoveryTime and archer.bow.mesh == Archer.rest_bow
			and not effects.has_node("NativeRatmanArrow"), "hands and bow string recover without changing the gait")


func replay_effect(world: Node3D, packet: PackedByteArray) -> void:
	var original: String = world.game.phase
	world.game.phase = "world"
	world.game._handle(packet)
	world.game.phase = original


func arrow_packet(source: int, target: int, at: Vector2i, target_at: Vector2i, id := 0xc0) -> PackedByteArray:
	var packet := PackedByteArray([id, 0])
	packet.append_array(Wire.uint_be(source, 4))
	packet.append_array(Wire.uint_be(target, 4))
	packet.append_array(Wire.uint_be(Arrow, 2))
	packet.append_array(Wire.uint_be(at.x, 2))
	packet.append_array(Wire.uint_be(at.y, 2))
	packet.append(0)
	packet.append_array(Wire.uint_be(target_at.x, 2))
	packet.append_array(Wire.uint_be(target_at.y, 2))
	packet.append_array(PackedByteArray([0, 18, 1, 0, 0, 0, 0]))
	packet.resize(49 if id == 0xc7 else 36)
	return packet
