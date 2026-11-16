# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-llama-world.gd"

const Source := 0x4601
const Target := 0x4602
const Breath := "reptalon/ReptalonFireBreath"
const RidingItem := 0x3e90


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	for child in world.get_children():
		if child.get_script() == preload("res://Network/MobileNames.gd"):
			child.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var tile := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	world.game._handle(mobile_packet(tile, Source, 276, 64))
	world.game._handle(mobile_packet(tile + Vector2i(3, 0), Target, 211, 0))
	world.game.phase = "world"
	var reptalon: Node3D = world.avatars[Source].horse_visual
	var presenter: Node3D
	for child in world.get_children():
		if child.has_method("_bolt_origin") and child.has_method("present"):
			presenter = child
			break
	assert(presenter != null and reptalon.fire_breath_origin() == null)
	world.game._handle(windup(10))
	assert(reptalon.current_clip == "Death2" and reptalon.dead)
	world.game._handle(mobile_packet(tile, Source + 10, 276, 64))
	reptalon = world.avatars[Source + 10].horse_visual
	world.game._handle(windup(5, Source + 10))
	assert(reptalon.current_clip == Breath and not reptalon.dead and reptalon.action_remaining > 1.3,
		str([reptalon.current_clip, reptalon.dead, reptalon.action_remaining, reptalon.native_body,
			reptalon.get_meta("native_mount_item", 0), reptalon.animator.get_animation_list(), world.game.last_mobile_actions]))
	reptalon.animator.advance(0.0)
	for frame in 78:
		if frame == 60:
			world.game._handle(reptalon_action_packet(Source + 10, 5, 5))
			world.game._handle(action_packet(Source + 10, 0, 1))
			reptalon.play_gait(true, 4.0)
		reptalon.animator.advance(1.0 / 60.0)
		reptalon._process(1.0 / 60.0)
	var muzzle: Variant = reptalon.fire_breath_origin()
	assert(muzzle is Vector3 and muzzle.distance_to(reptalon.socket("mouth").origin) < .00001,
		"Melee during windup must keep the native breath and muzzle")
	var before: int = presenter.get_child_count()
	world.game._handle(projectile(tile, Source + 10))
	assert(presenter.get_child_count() == before + 1)
	assert(presenter.get_child(before).global_position.distance_to(muzzle) < .00001)
	assert(world.avatars[Source].horse_visual.dead)
	reptalon._process(reptalon.action_remaining + .01)
	world.game._handle(reptalon_action_packet(Source + 10, 5, 5))
	assert(reptalon.current_clip == "Attack" and reptalon.fire_breath_origin() == null)
	world.game._handle(windup(5, Source + 10))
	world.game._handle(reptalon_action_packet(Source + 10, 8, 5))
	assert(reptalon.dead and reptalon.fire_breath_origin() == null)
	var corpse := 0x40000000 + Source + 10
	world.game._handle(corpse_packet(tile, corpse, 276, CorpseHue))
	world.game._handle(death_packet(Source + 10, corpse))
	world.creature_deaths.finish(Source + 10)
	await process_frame
	var frozen: Node3D = world.world_items.nodes[corpse].get_node_or_null("CorpseVisual")
	assert(frozen != null and frozen.get_meta("corpse_body") == 276 and frozen.get_meta("native_hue") == CorpseHue
		and frozen.find_children("*", "Skeleton3D", true, false).is_empty())
	var rider := Source + 20
	world.game._handle(mobile_packet(tile, rider, 400, 0))
	world.game._handle(wear_packet(rider, RidingItem, CorpseHue))
	var mounted: Node3D = world.avatars[rider].horse_visual
	assert(mounted != null and mounted.get_meta("native_mount_item", 0) == RidingItem and mounted.native_hue == CorpseHue)
	world.game._handle(windup(5, rider))
	assert(mounted.current_clip != Breath and not mounted.dead, "A rider action never fires the mount's breath")
	world.game.phase = "offline"
	print("REPTALON WORLD: 12 decoded breath, mount and corpse checks, Enhanced ",
		"--enhanced-creature-actions" in OS.get_cmdline_user_args())
	quit()


func windup(frames: int, serial := Source) -> PackedByteArray:
	return reptalon_action_packet(serial, 12, frames)


func reptalon_action_packet(serial: int, action: int, frames: int) -> PackedByteArray:
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(PackedByteArray([0, action, 0, frames, 0, 1, 0, 0, 0]))
	return packet


func projectile(tile: Vector2i, serial: int) -> PackedByteArray:
	var packet := PackedByteArray([0xc0, 0])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(Wire.uint_be(Target, 4))
	packet.append_array(Wire.uint_be(0x36d4, 2))
	packet.append_array(Wire.uint_be(tile.x, 2))
	packet.append_array(Wire.uint_be(tile.y, 2))
	packet.append(0)
	packet.append_array(Wire.uint_be(tile.x + 3, 2))
	packet.append_array(Wire.uint_be(tile.y, 2))
	packet.resize(36)
	packet[22] = 5
	return packet
