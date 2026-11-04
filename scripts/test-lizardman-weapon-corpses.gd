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
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var active := "--active" in OS.get_cmdline_user_args()
	var historic := Registry.entry(33)
	assert(historic.kind == "lizard_race_lizardman")
	for body in [35, 36]:
		var form := "Spear" if body == 35 else "Mace"
		var path := "res://local-art/creatures/lizardman-pillage-trial-%s.scn" % form.to_lower()
		var record := Registry.entry(body).duplicate(true)
		assert(not record.is_empty())
		if active:
			assert(record.status == "validated" and record.kind == "lizardman_" + form.to_lower())
			assert(record.assets.modern == path)
		else:
			record.assets = {"modern": path}
			record.presentation_script = "res://Presentation/SourceArmedLizardmanVisual.gd"
			Registry.entries[body] = record
		check_grip(body)
		for axis in [Vector3.RIGHT, Vector3.FORWARD]:
			for slope in [-0.14, 0.14]:
				await check_handoff(body, form, axis, slope)
		await check_handoff(body, form, Vector3.RIGHT, 0.0, 0.35)
		await check_handoff(body, form, Vector3.RIGHT, 0.0, -0.35)
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
				var expected_point := expected * source[i]
				error = maxf(error, expected_point.distance_to(frozen.transform * points[i]))
			assert(error < 0.0001)
			assert(frozen.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES] == null)
			print(body, " hue ", hue, " ", points.size(), " weapon vertices match the last skeletal pose; max error ", error)
			corpse.free()
			posed.queue_free()
	assert(Registry.entry(33) == historic)
	await process_frame
	quit()

func check_grip(body: int) -> void:
	var actor := Registry.create(body)
	root.add_child(actor)
	actor.apply_identity(body, 0)
	actor.set_physics_process(false)
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var angles: Dictionary = {}
	for clip in ["Walk", "Run", "Attack", "Pillage"]:
		player.play(clip, 0.0)
		player.advance(0.0)
		for sample in 9:
			player.seek(player.get_animation(clip).length * float(sample) / 8.0, true)
			for name in ["bip01 r finger0", "bip01 r finger01", "bip01 r finger1", "bip01 r finger11"]:
				var bone := rig.find_bone(name)
				assert(bone >= 0)
				var rotation := rig.get_bone_pose_rotation(bone)
				if not angles.has(name):
					angles[name] = rotation
				assert(rotation.angle_to(angles[name]) < 0.002)
	actor.free()

func check_handoff(body: int, form: String, axis: Vector3, slope: float, step_edge := INF) -> void:
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

	var stepped := is_finite(step_edge)
	var ground := StaticBody3D.new()
	arena.add_child(ground)
	ground.basis = Basis(axis, slope)
	var box := BoxShape3D.new()
	box.size = Vector3(10.0, 0.1, 10.0)
	var surface := CollisionShape3D.new()
	surface.shape = box
	surface.position.y = -0.05
	ground.add_child(surface)
	if stepped:
		var upper := CollisionShape3D.new()
		var stair := BoxShape3D.new()
		stair.size = Vector3(2.0, 0.22, 10.0)
		upper.shape = stair
		upper.position = Vector3(step_edge + 1.0, 0.11, 0.0)
		ground.add_child(upper)
	await physics_frame
	await physics_frame

	var killed := 10000 + body
	var serial := 0x40010000 + body
	var avatar := Avatar.new()
	arena.add_child(avatar)
	avatar.horse_visual = Registry.create(body)
	avatar.add_child(avatar.horse_visual)
	avatar.horse_visual.apply_identity(body, 0x8035)
	if step_edge < 0.0:
		avatar.position.y = 0.22
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
	var root_transform := visual.global_transform
	var duration := player.get_animation("Death").length
	for sample in 41:
		player.seek(duration * float(sample) / 40.0, true)
		visual.support_collapse()
		var clearance: float = visual.minimum_gap(visual.skeleton.global_transform, Vector3.ZERO, ground.basis.y)
		assert(clearance >= 0.0028 and visual.global_transform.is_equal_approx(root_transform))
		if stepped:
			assert_step_clearance(visual, step_edge)
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
	for i in vertices.size():
		var point := frozen.global_transform * vertices[i]
		assert(point.distance_to(expected * source[i]) < 0.0001)
		assert(bounds.grow(0.0001).has_point(holder.to_local(point)))
	assert(items.corpse_snapshots.has(serial))
	print(body, " step " if stepped else " slope ", axis, " ", slope, ": 41 collapse poses clear ground and corpse preserves world-space weapon pose")
	arena.queue_free()
	game.queue_free()
	await process_frame

func assert_step_clearance(visual: Node3D, step_edge: float) -> void:
	var rig: Skeleton3D = visual.skeleton
	for mesh: MeshInstance3D in visual.model.find_children("*", "MeshInstance3D", true, false):
		var transforms: Array[Transform3D] = []
		for i in mesh.skin.get_bind_count():
			var bone := mesh.skin.get_bind_bone(i)
			if bone < 0:
				bone = rig.find_bone(mesh.skin.get_bind_name(i))
			transforms.append(rig.global_transform * rig.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(i))
		for i in mesh.mesh.get_surface_count():
			var arrays := mesh.mesh.surface_get_arrays(i)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var stride := bones.size() / vertices.size()
			for vertex in vertices.size():
				var point := Vector3.ZERO
				for slot in stride:
					var index := vertex * stride + slot
					point += (transforms[bones[index]] * vertices[vertex]) * weights[index]
				var ground := 0.22 if point.x > step_edge + 0.0001 and point.x < step_edge + 1.9999 else 0.0
				assert(point.y - ground >= 0.0028)
