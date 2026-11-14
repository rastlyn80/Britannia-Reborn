# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-ordinary-horse-world.gd"

const Presenter := preload("res://Presentation/CreatureProjectilePresenter.gd")
const Source := 0x2350
const Target := 0x2351


func run() -> void:
	var world := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set_process(false)
	world.set_physics_process(false)
	world.game.set_process(false)
	world.game.player.facet = 1
	await process_frame
	var at := Vector2i(int(world.world.originX) + 5, int(world.world.originY) + 5)
	var to := at + Vector2i(4, 1)
	var effects: Node3D
	for child: Node in world.get_children():
		if child is Presenter:
			effects = child
			break
	if not expect(effects != null, "World installs the native projectile presenter"):
		return
	world.game._handle(mobile_packet(to, Target, 400, 0))
	for body: int in [400, 401]:
		world.game._handle(mobile_packet(at, Source, body, 0))
		var actor: Node3D = world.avatars[Source]
		for graphic: int in [0x27ac, 0x2804]:
			if not await verify_projectile(world, effects, actor, at, to, graphic):
				return
	if "--niporailem-projectile" in OS.get_cmdline_user_args() and not await verify_treasure(world, effects, at, to):
		return
	print("CITADEL PROJECTILE WORLD: ", checks, " checks, Enhanced ", world.enhanced_creature_actions)
	quit(0)


func verify_projectile(world: Node, effects: Node3D, actor: Node3D, at: Vector2i, to: Vector2i, graphic: int) -> bool:
	var shuriken := graphic == 0x27ac
	var rig: Skeleton3D = actor.human_visual.skeleton
	rig.force_update_all_bone_transforms()
	var origin := rig.to_global(rig.get_bone_global_pose(rig.find_bone("hand_r" if shuriken else "head")).origin)
	if not shuriken:
		origin -= actor.global_basis.z.normalized() * .09 + Vector3.UP * .057
	var previous := effects.get_child_count()
	var tweens := get_processed_tweens()
	var phase: String = world.game.phase
	world.game.phase = "world"
	world.game._handle(projectile_packet(at, to, graphic))
	world.game.phase = phase
	if not expect(effects.get_child_count() == previous + 1, "One decoded effect makes one projectile"):
		return false
	var projectile := effects.get_child(previous) as MeshInstance3D
	var label := "NativeShuriken" if shuriken else "NativeFukiyaDart"
	if not expect(projectile.name == label and projectile.mesh is ArrayMesh and projectile.global_position.distance_to(origin) < .002,
			"The real graphic selects a distinct mesh at the animated release point"):
		return false
	var next := get_processed_tweens().filter(func(tween: Tween): return tween not in tweens)
	if not expect(next.size() == 1, "One flight runs for the decoded packet"):
		return false
	var flight: Tween = next.front()
	flight.pause()
	var basis := projectile.global_basis
	flight.custom_step(.1)
	if not expect(projectile.global_position.distance_to(origin) > .05 and
		(shuriken != projectile.global_basis.is_equal_approx(basis)), "Projectile advances and the shuriken spins"):
		return false
	flight.custom_step(1.6)
	await process_frame
	return expect(not is_instance_valid(projectile), "The projectile is cleared after impact")


func verify_treasure(world: Node, effects: Node3D, at: Vector2i, to: Vector2i) -> bool:
	world.game._handle(mobile_packet(at, Source, 722, 0))
	var old_tweens := get_processed_tweens()
	var wire := projectile_packet(at, to, 0x0eef)
	wire[wire.size() - 1] = 1
	var phase: String = world.game.phase
	world.game.phase = "world"
	world.game._handle(wire)
	world.game.phase = phase
	var gold := effects.get_node_or_null("NativeFoolsGold") as MeshInstance3D
	if not expect(gold != null and gold.mesh is ArrayMesh, "The recorded gold graphic creates a coin heap"):
		return false
	var flight: Tween = get_processed_tweens().filter(func(tween: Tween): return tween not in old_tweens).front()
	flight.pause()
	var start := gold.global_position
	flight.custom_step(.43)
	if not expect(gold.global_position.y > start.y + .15 and gold.global_position.distance_to(start) > .5,
			"The gold heap tumbles along a rising arc"):
		return false
	flight.custom_step(.9)
	await process_frame
	return expect(not is_instance_valid(gold), "Impact clears the projectile")


func projectile_packet(at: Vector2i, to: Vector2i, graphic: int) -> PackedByteArray:
	var packet := PackedByteArray([0x70, 0])
	packet.append_array(Wire.uint_be(Source, 4))
	packet.append_array(Wire.uint_be(Target, 4))
	packet.append_array(Wire.uint_be(graphic, 2))
	for tile: Vector2i in [at, to]:
		packet.append_array(Wire.uint_be(tile.x, 2))
		packet.append_array(Wire.uint_be(tile.y, 2))
		packet.append(0)
	packet.append_array(PackedByteArray([5, 0, 0, 0, 0, 0]))
	return packet
