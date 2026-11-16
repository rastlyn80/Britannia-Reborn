# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-ordinary-horse-world.gd"

const ClassicBreath := preload("res://Presentation/SourceTerrainClassicFireGargoyleVisual.gd")
const EnhancedBreath := preload("res://Presentation/SourceEnhancedFireGargoyleVisual.gd")
const Effects := preload("res://Presentation/EffectPresenter.gd")
const Serial := 0x25196
const Body := 130


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	var effects: Node3D
	for child in world.get_children():
		if child is Effects:
			effects = child
			break
	if expect(effects != null, "Find the actual projectile presenter") and await check_breath(world, effects, at):
		print("FIRE GARGOYLE BREATH WORLD: ", checks, " checks, Enhanced ", world.enhanced_creature_actions)
		quit(0)


func check_breath(world: Node, effects: Node3D, at: Vector2i) -> bool:
	var mobile := mobile_packet(at, Serial, Body, 0x40)
	mobile[13] = CorpseHue >> 8
	mobile[14] = CorpseHue & 255
	world.game._handle(mobile)
	var actor: Node3D = world.avatars[Serial].horse_visual
	if not expect(actor != null and actor.native_hue == CorpseHue, "The dyed Fire Gargoyle uses the retained rig"):
		return false
	var player: AnimationPlayer = actor.animator
	var anchor := actor.global_transform
	var original := player.get_animation("Attack")
	world.game._handle(classic_action(12, 5))
	var expected := EnhancedBreath.Breath if world.enhanced_creature_actions else ClassicBreath.Breath
	if not expect(actor.current_clip == expected and actor.action_remaining > 1.3,
			"The exact native windup selects the fitted breath"):
		return false
	player.advance(0.0)
	var start: Vector3 = actor.fire_breath_origin()
	for frame in 78:
		if frame == 60:
			world.game._handle(classic_action(4, 5))
			world.game._handle(action_packet(Serial, 0, 1))
			actor.play_gait(true, 4.0)
		player.advance(1.0 / 60.0)
		actor._process(1.0 / 60.0)
	var muzzle: Variant = actor.fire_breath_origin()
	if not expect(muzzle is Vector3 and muzzle.is_finite() and muzzle.distance_to(start) > .06 and actor.global_transform == anchor
			and actor.get_meta("native_action").action == 12, "Both melee packets preserve the moving muzzle at 1.3 seconds"):
		return false
	muzzle = ClassicBreath.mouth_position(actor)
	var before := effects.get_child_count()
	world.game.phase = "world"
	world.game._handle(effect_packet(at))
	world.game.phase = "idle"
	if not expect(effects.get_child_count() == before + 1 and effects.get_child(before).global_position.is_equal_approx(muzzle),
			"The native fireball starts between the animated jaws"):
		return false
	actor._process(actor.action_remaining + .01)
	world.game._handle(classic_action(4, 5))
	if not expect(actor.current_clip == "Attack" and player.get_animation("Attack") == original
			and actor.fire_breath_origin() == null, "The ordinary attack resumes on schedule"):
		return false
	world.game._handle(classic_action(12, 5))
	world.game._handle(classic_action(2, 5))
	if not expect(actor.dead and actor.current_clip == "Death" and actor.fire_breath_origin() == null, "Native death interrupts the windup"):
		return false
	var corpse := 0x40000000 + Serial
	world.game._handle(corpse_packet(at, corpse, Body, CorpseHue))
	world.game._handle(death_packet(Serial, corpse))
	world.creature_deaths.finish(Serial)
	await process_frame
	var frozen: Node3D = world.world_items.nodes[corpse].get_node_or_null("CorpseVisual")
	return expect(frozen != null and frozen.get_meta("corpse_body") == Body
		and frozen.get_meta("native_hue") == CorpseHue and frozen.find_children("*", "Skeleton3D", true, false).is_empty(),
		"The native death builds the matching dyed static cadaver")


func classic_action(group: int, frames: int) -> PackedByteArray:
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(Serial, 4))
	packet.append_array(PackedByteArray([0, group, 0, frames, 0, 1, 0, 0, 0]))
	return packet


func effect_packet(at: Vector2i) -> PackedByteArray:
	var packet := PackedByteArray([0x70, 0])
	packet.append_array(Wire.uint_be(Serial, 4))
	packet.append_array(Wire.uint_be(Serial + 1, 4))
	packet.append_array(Wire.uint_be(0x36d4, 2))
	packet.append_array(Wire.uint_be(at.x, 2))
	packet.append_array(Wire.uint_be(at.y, 2))
	packet.append(0)
	packet.append_array(Wire.uint_be(at.x + 1, 2))
	packet.append_array(Wire.uint_be(at.y, 2))
	packet.append_array(PackedByteArray([0, 5, 0, 0, 0, 0, 0]))
	return packet
