extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")

const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Deaths := preload("res://Presentation/CreatureDeaths.gd")
const WorldItems := preload("res://Presentation/WorldItems.gd")

class Arena extends Node3D:
	var avatars: Dictionary = {}

class Avatar extends Node3D:
	var horse_visual: Node3D

func _initialize() -> void:
	create_timer(15.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	for body in [35, 36]:
		var form := "Spear" if body == 35 else "Mace"
		var record := Registry.entry(body).duplicate(true)
		assert(not record.is_empty())
		record.assets = {"modern": "res://local-art/creatures/lizardman-pillage-trial-%s.scn" % form.to_lower()}
		Registry.entries[body] = record
		await check_handoff(body, form)
		for hue in [0, 53, 0x8035]:
			var posed := Corpses.posed(body, hue)
			assert(posed != null)
			var weapon := posed.find_child(form, true, false) as MeshInstance3D
			var rig := weapon.get_parent() as Skeleton3D
			var bone := rig.find_bone("lizardman weapon")
			assert(bone >= 0 and weapon.skin.get_bind_bone(0) == bone)
			var expected := posed.global_transform.affine_inverse() * rig.global_transform * rig.get_bone_global_pose(bone)
			var corpse := Corpses.freeze(posed)
			assert(corpse != null and corpse.get_meta("graphic_id") == 0x2006)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			var frozen := corpse.get_node(form) as MeshInstance3D
			assert(frozen != null)
			var points: PackedVector3Array = frozen.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			assert(points.size() == (84 if body == 35 else 270))
			var source: PackedVector3Array = weapon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var lift := (frozen.transform * points[0]).y - (expected * source[0]).y
			var error := 0.0
			for i in points.size():
				var expected_point := expected * source[i] + Vector3.UP * lift
				error = maxf(error, expected_point.distance_to(frozen.transform * points[i]))
			assert(error < 0.0001)
			assert(frozen.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES] == null)
			print(body, " hue ", hue, " ", points.size(), " weapon vertices match the last skeletal pose; max error ", error)
			corpse.free()
			posed.queue_free()
	await process_frame
	quit()

func check_handoff(body: int, form: String) -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var arena := Arena.new()
	root.add_child(arena)
	var items := WorldItems.new()
	arena.add_child(items)
	items.add_child(items.hint)
	items.session = game
	var deaths := Deaths.new()
	arena.add_child(deaths)
	deaths.configure(arena, game, items)
	deaths.set_process(false)

	var killed := 10000 + body
	var serial := 0x40010000 + body
	var avatar := Avatar.new()
	arena.add_child(avatar)
	avatar.horse_visual = Registry.create(body)
	avatar.add_child(avatar.horse_visual)
	avatar.horse_visual.apply_identity(body, 0x8035)
	arena.avatars[killed] = avatar
	game.entities[killed] = {"serial": killed, "body": body, "hue": 0x8035, "direction": 5}
	var holder := Node3D.new()
	items.add_child(holder)
	items.nodes[serial] = holder
	assert(items._equine_corpse(holder, {"id": 0x2006, "amount": body, "hue": 0x8035, "direction": 5}, serial))

	var packet := PackedByteArray([0xaf])
	packet.append_array(Wire.uint_be(killed, 4))
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(Wire.uint_be(0, 4))
	game._handle(packet)
	assert(deaths.active.has(killed) and not holder.visible and not avatar.visible)
	var visual: Node3D = deaths.active[killed].visual
	assert(visual.native_body == body and visual.native_hue == 0x8035)
	var player: AnimationPlayer = visual.animator
	player.play("Death", 0.0)
	player.advance(0.0)
	player.seek(player.get_animation("Death").length, true)
	player.pause()
	var weapon := visual.find_child(form, true, false) as MeshInstance3D
	var rig := weapon.get_parent() as Skeleton3D
	rig.force_update_all_bone_transforms()
	var expected := rig.global_transform * rig.get_bone_global_pose(weapon.skin.get_bind_bone(0))
	var source: PackedVector3Array = weapon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

	var removal := PackedByteArray([0x1d])
	removal.append_array(Wire.uint_be(killed, 4))
	game._handle(removal)
	arena.avatars.erase(killed)
	avatar.queue_free()
	await process_frame
	assert(is_instance_valid(visual) and not holder.visible)
	deaths._process(float(deaths.active[killed].remaining) + 0.1)
	assert(holder.visible and deaths.active.is_empty())
	var cadaver := holder.get_node("CorpseVisual") as Node3D
	assert(cadaver.get_meta("corpse_body") == body and cadaver.get_meta("native_hue") == 0x8035)
	var frozen := cadaver.get_node(form) as MeshInstance3D
	var vertices: PackedVector3Array = frozen.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var bounds: AABB = cadaver.transform * cadaver.get_meta("corpse_bounds")
	var pick := holder.get_node("PickBody/PickShape") as CollisionShape3D
	assert(pick.position.is_equal_approx(bounds.get_center()) and source.size() == vertices.size())
	var lift := (frozen.global_transform * vertices[0]).y - (expected * source[0]).y
	for i in vertices.size():
		var point := frozen.global_transform * vertices[i]
		assert(point.distance_to(expected * source[i] + Vector3.UP * lift) < 0.0001)
		assert(bounds.grow(0.0001).has_point(holder.to_local(point)))
	print(body, " decoded death/removal preserves weapon and world item picking")
	arena.queue_free()
	game.queue_free()
