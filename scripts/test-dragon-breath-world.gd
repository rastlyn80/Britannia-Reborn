# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-ordinary-horse-world.gd"

const Dragon := preload("res://Presentation/SourceDragonBreathVisual.gd")
const Effects := preload("res://Presentation/EffectPresenter.gd")
const Serpentine := preload("res://Presentation/SerpentineDragonBreath.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")


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
	if not expect(effects != null, "Find the World projectile presenter"):
		return
	for body: int in [12, 46, 59, 60, 61, 106]:
		if not check_breath(world, effects, at, body):
			return
	if not await check_serpentine(world, effects, at):
		return
	if not check_serpentine_ground():
		return
	print("DRAGON BREATH WORLD: ", checks, " checks, Enhanced ", world.enhanced_creature_actions)
	quit(0)


func check_breath(world: Node, effects: Node3D, at: Vector2i, body: int) -> bool:
	var serial := 0x25100 + body
	world.game._handle(mobile_packet(at, serial, body, 0x40))
	var actor := world.avatars[serial].horse_visual as Dragon
	if not expect(actor != null and actor.fire_breath_origin() == null, "Source dragon begins without a breath"):
		return false
	world.game._handle(classic_packet(serial, 12))
	var breath_clip := actor.current_clip
	if not expect(actor.fire_breath_origin() is Vector3 and actor.action_remaining >= 1.5,
			"Native windup stays active for the delayed projectile, body %d" % body):
		return false
	actor.animator.advance(0.0)
	for frame in 78:
		if frame == 60:
			world.game._handle(classic_packet(serial, 4))
			world.game._handle(action_packet(serial, 0, 1))
			actor.play_gait(true, 4.0)
		actor.animator.advance(1.0 / 60.0)
		actor._process(1.0 / 60.0)
	var muzzle: Variant = actor.fire_breath_origin()
	if not expect(muzzle is Vector3 and actor.get_meta("native_action").action == 12,
			"Native melee and locomotion preserve the muzzle at 1.3 seconds, body %d" % body):
		return false
	var before := effects.get_child_count()
	world.game.phase = "world"
	world.game._handle(projectile_packet(serial, at))
	world.game.phase = "idle"
	if not expect(effects.get_child_count() == before + 1, "The delayed effect creates a projectile"):
		return false
	var bolt := effects.get_child(before) as MeshInstance3D
	if not expect(bolt != null and bolt.global_position.is_equal_approx(muzzle), "The projectile leaves the mouth"):
		return false
	actor._process(actor.action_remaining + 0.01)
	world.game._handle(classic_packet(serial, 4))
	if not expect(actor.current_clip != breath_clip and actor.get_meta("native_action").action == 4,
			"Ordinary melee resumes when the breath ends"):
		return false
	world.game._handle(classic_packet(serial, 12))
	world.game._handle(classic_packet(serial, 2))
	return expect(actor.dead and actor.fire_breath_origin() == null, "Death interrupts a breath")


func classic_packet(serial: int, group: int) -> PackedByteArray:
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(PackedByteArray([0, group, 0, 5, 0, 1, 0, 0, 0]))
	return packet


func check_serpentine(world: Node, effects: Node3D, at: Vector2i) -> bool:
	const Serial := 0x25167
	var living := mobile_packet(at, Serial, Serpentine.Body, 0x40)
	living[13] = CorpseHue >> 8
	living[14] = CorpseHue & 255
	world.game._handle(living)
	var actor: Node3D = world.avatars[Serial].horse_visual
	var original_length: float = actor.animator.get_animation("Attack").length
	var base_pose := actor.skeleton.find_bone(Serpentine.MuzzleBone) as int
	if not expect(base_pose >= 0 and actor.native_hue == CorpseHue, "Original Serpentine rig and native hue"):
		return false
	world.game._handle(classic_packet(Serial, 12))
	if not expect(actor.current_clip == Serpentine.Clip and is_equal_approx(actor.action_remaining, Serpentine.Duration),
			"The stock action selects the Serpentine breath windup"):
		return false
	actor.animator.advance(0.0)
	var start: Vector3 = Serpentine.origin(actor)
	for frame in 78:
		if frame == 60:
			world.game._handle(classic_packet(Serial, 4))
			world.game._handle(action_packet(Serial, 0, 1))
		actor.animator.advance(1.0 / 60.0)
		actor._process(1.0 / 60.0)
	var muzzle: Variant = Serpentine.origin(actor)
	if not expect(muzzle is Vector3 and muzzle.distance_to(start) > 0.15 and actor.current_clip == Serpentine.Clip,
			"Muzzle follows the windup through both melee packet types"):
		return false
	var before := effects.get_child_count()
	world.game.phase = "world"
	world.game._handle(projectile_packet(Serial, at))
	world.game.phase = "idle"
	if not expect(effects.get_child_count() == before + 1 and effects.get_child(before).global_position.is_equal_approx(muzzle),
			"The delayed native graphic launches from the animated Serpentine snout"):
		return false
	actor._process(actor.action_remaining + 0.01)
	world.game._handle(classic_packet(Serial, 4))
	if not expect(actor.current_clip == "Attack" and actor.animator.get_animation("Attack").length == original_length
			and Serpentine.origin(actor) == null, "The existing melee clip resumes at its original length"):
		return false
	world.game._handle(classic_packet(Serial, 12))
	world.game._handle(classic_packet(Serial, 2))
	if not expect(actor.dead and Serpentine.origin(actor) == null, "Death interrupts the Serpentine breath"):
		return false
	var corpse := 0x40000000 + Serial
	world.game._handle(corpse_packet(at, corpse, Serpentine.Body, CorpseHue))
	world.game._handle(death_packet(Serial, corpse))
	world.creature_deaths.finish(Serial)
	await process_frame
	var frozen: Node3D = world.world_items.nodes[corpse].get_node_or_null("CorpseVisual")
	return expect(frozen != null and frozen.get_meta("corpse_body") == Serpentine.Body
		and frozen.get_meta("native_hue") == CorpseHue and frozen.find_children("*", "Skeleton3D", true, false).is_empty(),
		"The interrupted creature leaves its original dyed static corpse")


func check_serpentine_ground() -> bool:
	var registry := preload("res://Presentation/CreatureRegistry.gd")
	var poses := 0
	var lowest := INF
	for treatment: String in ["original", "rounded", "modern"]:
		var actor := registry.create(Serpentine.Body)
		actor.treatment = treatment
		root.add_child(actor)
		actor.apply_identity(Serpentine.Body, 0)
		var player: AnimationPlayer = actor.animator
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var anchor := actor.global_transform
		var rig: Skeleton3D = actor.skeleton
		var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh, rig)
		var windup: Dictionary = preload("res://Network/MobileAppearance.gd").action(classic_packet(1, 12))
		if not expect(Serpentine.play(actor, windup), "The retained %s rig binds the breath" % treatment):
			return false
		player.advance(0.0)
		for normal: Vector3 in [Vector3.UP, Vector3(0.12, 1.0, 0.0).normalized(), Vector3(0.0, 1.0, -0.12).normalized()]:
			for frame in 31:
				player.seek(Serpentine.Duration * frame / 30.0, true)
				actor.contact.contacts[0] = {"normal": normal, "position": Vector3.ZERO}
				actor.contact.modification_processed.emit()
				var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, normal)
				if not expect(gap > 0.0004 and actor.global_transform == anchor,
						"Breath skin clears the support plane, %s frame %d gap %f" % [treatment, frame, gap]):
					return false
				lowest = minf(lowest, gap)
				poses += 1
		actor.free()
	print("SERPENTINE BREATH GROUND: ", poses, " poses; minimum gap ", lowest)
	return true


func projectile_packet(serial: int, at: Vector2i) -> PackedByteArray:
	var packet := PackedByteArray([0x70, 0])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(Wire.uint_be(serial + 1, 4))
	packet.append_array(Wire.uint_be(0x36d4, 2))
	packet.append_array(Wire.uint_be(at.x, 2))
	packet.append_array(Wire.uint_be(at.y, 2))
	packet.append(0)
	packet.append_array(Wire.uint_be(at.x + 1, 2))
	packet.append_array(Wire.uint_be(at.y, 2))
	packet.append_array(PackedByteArray([0, 5, 0, 0, 0, 0, 0]))
	return packet
