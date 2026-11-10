# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Game := preload("res://Network/GameSession.gd")
const Items := preload("res://Presentation/WorldItems.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Login := preload("res://Network/LoginProtocol.gd")
const Artwork := preload("res://Network/Artwork.gd")
const SERIAL := 0x40000021
const DYE := 1109

class Arena extends Node3D:
	var world := {"originX": 1600, "originY": 1100, "width": 4, "height": 4,
		"elevationScale": 0.1, "statics": [], "terrain": [], "staticData": {}}
	var movement_surface: RefCounted
	var reconstruction := preload("res://Presentation/Reconstruction.gd").new()
	func entity_point(x: int, y: int, z: int) -> Vector3:
		return Vector3(x - world.originX, z * .1, y - world.originY)

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	Artwork.load_local()
	if not Artwork.hues.has(str(DYE - 1)):
		var fixture: Array[int] = []
		for shade in 32:
			fixture.append((shade << 10) | (shade << 5))
		Artwork.hues[str(DYE - 1)] = fixture
	var arena := Arena.new()
	root.add_child(arena)
	var game := Game.new()
	arena.add_child(game)
	game.phase = "world"
	game.set_process(false)
	var items := Items.new()
	arena.add_child(items)
	items.configure(arena, game)
	items.set_process(false)
	var bodies := [205]
	for body in [60, 61]:
		if Corpses.supports(body): bodies.append(body)
	for body: int in bodies:
		var actor := Corpses.posed(body, 0)
		assert(actor != null and actor.has_method("corpse_snapshot_floor"))
		actor.global_position = Vector3(1.31, .14, .45)
		var snapshot := Snapshot.capture(actor, .04)
		assert(not snapshot.is_empty())
		actor.free()
		game._handle(corpse_packet(body, 0))
		items.retain_corpse_snapshot(SERIAL, snapshot)
		var old: Node3D = items.nodes[SERIAL].get_node("CorpseVisual")
		var placement := old.global_transform
		var before := surface_meshes(old)
		assert(placement == snapshot.placement and old.get_meta("native_hue") == 0)
		game._handle(corpse_packet(body, DYE))
		var current: Node3D = items.nodes[SERIAL].get_node("CorpseVisual")
		assert(game.world_items[SERIAL].hue == DYE and current.get_meta("native_hue") == DYE)
		assert(current.global_transform == placement and surface_meshes(current) == before)
		var catalogue := Corpses.build(body, DYE)
		assert(check_dye(current, catalogue))
		catalogue.free()
		var remove := PackedByteArray([0x1d])
		remove.append_array(Login.uint_be(SERIAL, 4))
		game._handle(remove)
		assert(not items.nodes.has(SERIAL) and not items.corpse_snapshots.has(SERIAL))
	arena.free()
	print("CORPSE SNAPSHOT HUE: native item updates preserve fitted poses and apply the new materials ", bodies)
	quit()

func corpse_packet(body: int, hue: int) -> PackedByteArray:
	var packet := PackedByteArray([0xf3, 0, 1, 0])
	packet.append_array(Login.uint_be(SERIAL, 4))
	packet.append_array(Login.uint_be(0x2006, 2))
	packet.append(0)
	packet.append_array(Login.uint_be(body, 2))
	packet.append_array(Login.uint_be(body, 2))
	packet.append_array(Login.uint_be(1601, 2))
	packet.append_array(Login.uint_be(1100, 2))
	packet.append_array([0, 0])
	packet.append_array(Login.uint_be(hue, 2))
	packet.append_array([0, 0, 0])
	return packet

func surface_meshes(cadaver: Node3D) -> Array:
	var meshes := []
	for part: MeshInstance3D in cadaver.get_children():
		meshes.append([part.mesh, part.transform])
	return meshes

func check_dye(cadaver: Node3D, reference: Node3D) -> bool:
	var verified := 0
	for part: MeshInstance3D in cadaver.get_children():
		var expected := reference.get_node(NodePath(part.name)) as MeshInstance3D
		for surface in part.mesh.get_surface_count():
			var actual := part.get_active_material(surface)
			var wanted := expected.get_active_material(surface)
			if actual is ShaderMaterial and wanted is ShaderMaterial:
				assert(actual.shader == wanted.shader)
				var palette: Variant = wanted.get_shader_parameter("hue_palette")
				if palette != null:
					assert(actual.get_shader_parameter("hue_palette") == palette)
					verified += 1
	return verified > 0
