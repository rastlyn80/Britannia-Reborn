# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-later-creature-world.gd"

const Body := 265
const Hue := 0x47E
const Effects := preload("res://Presentation/EffectPresenter.gd")
const Breath := preload("res://Presentation/SourceTerrainClassicHydraVisual.gd")


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var at := Vector2i(int(world.world.originX) + 4, int(world.world.originY) + 4)
	var serial := 0x37501
	create_actor(world, at, serial, Body, 64, Hue)
	var targets := [at + Vector2i(5, -1), at + Vector2i(5, 0), at + Vector2i(5, 1)]
	for index in targets.size():
		create_actor(world, targets[index], serial + index + 1, 400, 0, 0)
	var hydra: Node3D = world.avatars[serial].horse_visual
	if not expect(hydra != null and hydra.native_body == Body and hydra.native_hue == Hue,
			"Crystal Hydra selects the retained five-headed rig and its constructor hue"):
		return
	var effect_presenter: Node3D
	for node in world.get_children():
		if node is Effects:
			effect_presenter = node
			break
	if not expect(effect_presenter != null, "Regular World listens for breath effects"):
		return
	var request := PackedByteArray([0x6E])
	request.append_array(Wire.uint_be(serial, 4))
	request.append_array(PackedByteArray([0, 12, 0, 5, 0, 1, 0, 0, 0]))
	world.game._handle(request)
	if not expect(hydra.fire_breath_origin() is Vector3 and hydra.action_remaining >= 1.5,
			"The stock forward group 12 selects the breath windup"):
		return
	hydra.animator.advance(0.0)
	for frame in 78:
		if frame == 60:
			classic_action(world, serial, 4)
			world.game._handle(action_packet(serial, 0, 1))
		hydra.animator.advance(1.0 / 60.0)
		hydra._process(1.0 / 60.0)
	if not expect(hydra.fire_breath_origin() is Vector3 and hydra.get_meta("native_action").action == 12,
			"Classic and Enhanced melee preserve the breath through release"):
		return
	var origin := Breath.mouth_position(hydra)
	var phase: String = world.game.phase
	world.game.phase = "world"
	for index in targets.size():
		var count := effect_presenter.get_child_count()
		world.game._handle(cold_bolt(serial, serial + index + 1, at, targets[index]))
		if not expect(effect_presenter.get_child_count() == count + 1, "A separate bolt is created for each target"):
			return
		var bolt := effect_presenter.get_child(count) as MeshInstance3D
		var material := bolt.material_override as StandardMaterial3D
		var colour := Effects.colour({"graphic": 0x36d4, "hue": Hue})
		if not expect(bolt.global_position.is_equal_approx(origin) and material.albedo_color.is_equal_approx(colour),
				"Each cold bolt starts at the animated mouth and keeps the server hue"):
			return
	world.game.phase = phase
	classic_action(world, serial, 2)
	if not await check_corpse(world, at, serial, Body, Hue, "Death"):
		return
	print("CRYSTAL HYDRA WORLD: ", checks, " checks, Enhanced ", world.enhanced_creature_actions)
	quit(0)


func cold_bolt(serial: int, target: int, start: Vector2i, end: Vector2i) -> PackedByteArray:
	var effect := PackedByteArray([0xC0, 0])
	effect.append_array(Wire.uint_be(serial, 4))
	effect.append_array(Wire.uint_be(target, 4))
	effect.append_array(Wire.uint_be(0x36D4, 2))
	for tile in [start, end]:
		effect.append_array(Wire.uint_be(tile.x, 2))
		effect.append_array(Wire.uint_be(tile.y, 2))
		effect.append(0)
	effect.append_array(PackedByteArray([5, 0, 0, 0, 0, 0]))
	effect.append_array(Wire.uint_be(Hue, 4))
	effect.append_array(Wire.uint_be(0, 4))
	return effect
