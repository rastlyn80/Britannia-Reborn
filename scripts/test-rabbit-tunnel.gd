# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Game := preload("res://Network/GameSession.gd")
const Events := preload("res://Presentation/CreatureEventPresenter.gd")
const Dig := preload("res://Presentation/RabbitTunnelPose.gd")
const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Rules := preload("res://Presentation/RegionalRules.gd")
const Login := preload("res://Network/LoginProtocol.gd")
const Items := preload("res://Presentation/WorldItems.gd")
const Actions := preload("res://Presentation/NativeMobileActions.gd")
const NOTICE := 1114450
const HOLE_SERIAL := 0x40000005

class Arena extends Node3D:
	var avatars := {}
	var game: Node
	var world := {"originX": 1219, "originY": 1714, "width": 4, "height": 4,
		"elevationScale": 0.1, "statics": [], "terrain": [], "staticData": {}}
	var movement_surface: RefCounted
	var reconstruction := preload("res://Presentation/Reconstruction.gd").new()
	func entity_point(x: int, y: int, z: int) -> Vector3:
		return Vector3(x - world.originX, z * 0.1, y - world.originY)

func _initialize() -> void:
	create_timer(24.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func notice(serial: int, body := 205, cliloc := NOTICE, kind := 0) -> PackedByteArray:
	var wire := PackedByteArray([0xc1, 0, 50])
	wire.append_array(Login.uint_be(serial, 4))
	wire.append_array(Login.uint_be(body, 2))
	wire.append_array([kind, 0x03, 0xb2, 0, 3])
	wire.append_array(Login.uint_be(cliloc, 4))
	wire.resize(50)
	return wire

func avatar(arena: Arena, serial: int, at: Vector3) -> Avatar:
	var actor := Avatar.new()
	actor.initial_body = 205
	actor.position = at
	arena.add_child(actor)
	actor.apply_server_appearance({"body": 205, "hue": 0x480 if serial == 3 else 0}, [])
	arena.avatars[serial] = actor
	arena.game.entities[serial] = {"body": 205}
	return actor

func classic(serial: int, action: int) -> PackedByteArray:
	var wire := PackedByteArray([0x6e])
	wire.append_array(Login.uint_be(serial, 4))
	wire.append_array(Login.uint_be(action, 2))
	wire.append_array([0, 5, 0, 1, 0, 0, 1])
	return wire

func run() -> void:
	assert(Rules.resolve(0x0913, {}).get("decal") == "rabbit tunnel")
	assert(Rules.resolve(0x0914, {}).get("decal", "") != "rabbit tunnel")
	var arena := Arena.new()
	root.add_child(arena)
	arena.game = Game.new()
	arena.add_child(arena.game)
	arena.game.phase = "world"
	arena.game.set_process(false)
	var ground := make_ground()
	arena.add_child(ground)
	if "--slope" in OS.get_cmdline_user_args():
		ground.rotation = Vector3(.10, 0, -.12)
	var normal := ground.global_basis.y.normalized()
	var actor := avatar(arena, 3, Vector3.ZERO)
	var neighbor := avatar(arena, 4, Vector3(.5, 0, -.28))
	var event := Events.new()
	arena.add_child(event)
	event.configure(arena)
	var messages: Array = []
	arena.game.speech_received.connect(func(serial: int, label: String, type: int, _hue: int):
		messages.append([serial, label, type]))
	arena.game.mobile_action_received.connect(func(request: Dictionary):
		Actions.dispatch(arena.avatars[request.serial], request))
	var rabbit: Node3D = actor.horse_visual
	var adjacent: Node3D = neighbor.horse_visual
	var rig: Skeleton3D = rabbit.skeleton
	for wrong: PackedByteArray in [notice(3, 204), notice(3, 205, NOTICE + 1), notice(3, 205, NOTICE, 6), notice(999)]:
		arena.game._handle(wrong)
	assert(not rig.has_node("NativeTunnelPose") and not adjacent.skeleton.has_node("NativeTunnelPose"))
	var items := Items.new()
	arena.add_child(items)
	items.configure(arena, arena.game)
	items.set_process(false)
	var hole_packet := PackedByteArray([0xf3, 0, 1, 0])
	hole_packet.append_array(Login.uint_be(HOLE_SERIAL, 4))
	hole_packet.append_array(Login.uint_be(0x0913, 2))
	hole_packet.append_array([0, 0, 1, 0, 1])
	hole_packet.append_array(Login.uint_be(1219, 2))
	hole_packet.append_array(Login.uint_be(1714, 2))
	hole_packet.append_array([0, 0, 0, 1, 0, 0, 0])
	arena.game._handle(hole_packet)
	var item: Node3D = items.nodes[HOLE_SERIAL]
	assert(arena.game.world_items[HOLE_SERIAL].hue == 1)
	assert(item.get_node("BuilderVisual").get_meta("model") == "decal")
	assert(item.get_node("PickBody").collision_layer == 4)
	var source_xform := actor.global_transform
	await create_timer(.28).timeout
	arena.game._handle(notice(3))
	var dig := rig.get_node("NativeTunnelPose") as Dig
	assert(dig != null and not adjacent.skeleton.has_node("NativeTunnelPose"))
	assert(messages[-1] == [3, arena.game.labels.resolve(NOTICE), 0])
	var samples := {"left": 0.0, "right": 0.0, "sink": INF, "anchor": 0, "frames": 0, "strike": INF}
	var left := rig.find_bone("FrontPaw_L")
	var right := rig.find_bone("FrontPaw_R")
	var hips := rig.find_bone("Hips")
	dig.modification_processed.connect(func():
		var t := dig.elapsed
		if t > .62 and t < 3.40:
			var a := rig.to_global(rig.get_bone_global_pose(left).origin)
			var b := rig.to_global(rig.get_bone_global_pose(right).origin)
			samples.left = maxf(samples.left, a.y - b.y)
			samples.right = maxf(samples.right, b.y - a.y)
			samples.strike = minf(samples.strike, minf(a.dot(normal), b.dot(normal)))
		if t > 4.82 and t < 5.00:
			samples.sink = minf(samples.sink, rig.to_global(rig.get_bone_global_pose(hips).origin).y)
		if actor.global_transform != source_xform: samples.anchor += 1
		samples.frames += 1)
	await create_timer(.93).timeout
	var before := dig.elapsed
	arena.game._handle(notice(3))
	assert(rig.get_node("NativeTunnelPose") == dig and dig.elapsed == before)
	arena.game._handle(classic(3, 10))
	arena.game._handle(classic(4, 10))
	assert(rabbit.current_clip == "Idle" and adjacent.current_clip != "Idle")
	await create_timer(2.98).timeout
	await create_timer(.98).timeout
	await create_timer(.35).timeout
	assert(not rig.has_node("NativeTunnelPose") and not adjacent.skeleton.has_node("NativeTunnelPose"))
	assert(samples.left > .018 and samples.right > .018 and samples.sink < -.42 and samples.anchor == 0, str(samples))
	assert(samples.strike > -.045, str(samples))
	arena.game._handle(notice(4))
	assert(adjacent.skeleton.has_node("NativeTunnelPose"))
	arena.game._handle(classic(4, 8))
	await create_timer(.1).timeout
	assert(adjacent.dead and not adjacent.skeleton.has_node("NativeTunnelPose"))
	arena.game._handle(notice(4))
	assert(not adjacent.skeleton.has_node("NativeTunnelPose"))
	var remove := PackedByteArray([0x1d])
	remove.append_array(Login.uint_be(HOLE_SERIAL, 4))
	arena.game._handle(remove)
	assert(not arena.game.world_items.has(HOLE_SERIAL) and not items.nodes.has(HOLE_SERIAL))
	print("RABBIT TUNNEL: wire notice and hole, fidget priority, descent, recovery and death ", samples)
	quit()

func make_ground() -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var block := BoxShape3D.new()
	block.size = Vector3(7.0, .1, 7.0)
	collision.shape = block
	collision.position.y = -.05
	body.add_child(collision)
	return body
