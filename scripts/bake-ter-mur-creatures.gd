# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")
const Appearance := preload("res://Presentation/GargoyleAppearance.gd")
const HornStyle := {
	# Each silhouette is fitted to the corresponding Classic paperdoll layer.
	# Root x, root depth, root height, sweep, rise, curl, radius, pair count.
	0x4258: [.073, -.023, .174, .038, .084, -.021, .030, 2],
	0x4259: [.068, -.016, .153, .089, .119, .015, .024, 2],
	0x425a: [.000, -.086, .117, .000, .094, -.041, .026, 1],
	0x425b: [.079, -.003, .137, .063, .034, -.061, .044, 2],
	0x425c: [.066, -.028, .163, .027, .068, .028, .027, 2],
	0x425d: [.054, -.004, .168, .023, .165, -.035, .033, 2],
	0x425e: [.070, -.034, .152, .073, .107, -.054, .033, 2],
	0x425f: [.073, -.014, .141, .106, .079, -.058, .042, 2],
	0x4261: [.067, -.033, .141, .062, .042, -.028, .023, 2],
	0x4262: [.075, -.007, .134, .071, .041, -.081, .037, 2],
	0x4273: [.065, -.037, .163, .045, .072, -.049, .026, 2],
	0x4274: [.063, -.016, .169, .012, .102, .055, .030, 2],
	0x4275: [.060, -.021, .168, .041, .088, -.006, .024, 2],
	0x42aa: [.056, -.027, .168, .015, .139, -.011, .022, 2],
	0x42ab: [.059, -.031, .159, .041, .110, .034, .025, 4],
	0x42b1: [.063, -.032, .152, .052, .092, -.058, .031, 2],
	0x42b0: [.030, -.109, .035, .004, -.071, -.012, .014, 1],
	0x42ad: [.046, -.089, .053, .049, .031, -.032, .020, 2],
	0x42ae: [.048, -.069, .078, .042, -.047, -.064, .016, 2],
	0x42af: [.032, -.109, .042, .022, -.054, -.014, .018, 2],
}
const Forms := {
	293: [276, Vector3(.52, .64, .43), Color("#cbd9d0"), .75, .08, "Vollem"],
	666: [4, Vector3(.69, .73, .69), Color("#777477"), .86, .0, "Male Gargoyle"],
	667: [4, Vector3(.60, .69, .65), Color("#949493"), .86, .0, "Female Gargoyle"],
	739: [25, Vector3(1.12, 1.02, 1.17), Color("#ac7137"), .79, .02, "Leather Wolf"],
}
const Styles := ["original", "rounded", "modern"]

func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var folder := OS.get_environment("BR_TER_MUR_OUTPUT")
	assert(folder.is_absolute_path() and DirAccess.dir_exists_absolute(folder))
	var bodies := {}
	for body: int in Forms:
		var recipe: Array = Forms[body]
		var donor := Registry.entry(recipe[0])
		assert(not donor.is_empty())
		var row := {"name": recipe[5], "source_body": recipe[0], "donor_sha256": {}, "asset_sha256": {},
			"dimensions": [recipe[1].x, recipe[1].y, recipe[1].z]}
		for style: String in Styles:
			var path := Registry.asset_path(donor, style)
			var digest := FileAccess.get_sha256(path)
			assert(digest.length() == 64 and digest == donor.asset_sha256[style], path)
			row.donor_sha256[style] = digest
			row.asset_sha256[style] = bake_scene(folder, body, style, recipe, path)
		bodies[str(body)] = row
	var output := FileAccess.open(folder.path_join("profile.json"), FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify({"schema": 1, "bodies": bodies}, "  ", true, true))
	print("TER MUR BAKE: ", bodies.size(), " bodies, ", bodies.size() * Styles.size(), " scenes")
	quit(0)


func bake_scene(folder: String, body: int, style: String, recipe: Array, path: String) -> String:
	var donor := load(path) as PackedScene
	assert(donor != null)
	var model := donor.instantiate() as Node3D
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var animator := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var local_scale: Vector3 = recipe[1]
	model.scale *= local_scale
	model.position *= local_scale
	var geometry := ArrayMesh.new()
	var regions := skin_regions(mesh, rig, body)
	var donor_mesh := mesh.mesh as ArrayMesh
	for surface in donor_mesh.get_surface_count():
		var source := donor_mesh.surface_get_material(surface) as StandardMaterial3D
		assert(source != null and source.albedo_texture != null)
		var finish := source.duplicate() as StandardMaterial3D
		finish.albedo_color = recipe[2]
		finish.roughness = float(recipe[3])
		finish.metallic = float(recipe[4])
		finish.set_meta("ter_mur_finish", true)
		var arrays := donor_mesh.surface_get_arrays(surface)
		for graphic: int in regions[surface]:
			var triangles: PackedInt32Array = regions[surface][graphic]
			arrays[Mesh.ARRAY_INDEX] = triangles
			var format := donor_mesh.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
			geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format)
			var material := finish.duplicate() as StandardMaterial3D
			if body == 739 and graphic:
				material.albedo_color = Color("#48301e") if graphic == 1 else Color("#d08d40")
				material.roughness = .82 if graphic == 1 else .65
				material.metallic = .07
			elif graphic:
				material.set_meta("ter_mur_armor_id", graphic)
			geometry.surface_set_material(geometry.get_surface_count() - 1, material)
	mesh.mesh = geometry
	if body in [666, 667]:
		posture_gargoyle(animator, rig)
		add_gargoyle_equipment(model, rig, animator)
	if body == 293 and not animator.has_animation("Fly"):
		add_vollem_flight(animator)
	assert(animator.has_animation("Idle") and animator.has_animation("Walk") and animator.has_animation("Death"))
	animator.deterministic = true
	animator.play("Idle", 0.0)
	animator.seek(0.0, true)
	animator.advance(0.0)
	rig.force_update_all_bone_transforms()
	var bounds := Geometry.deformed_bounds(mesh, rig)
	assert(bounds.position.is_finite() and bounds.size.is_finite())
	var height := bounds.size.y
	assert(height > .35 and height < 2.6, "Implausible scaled height for %d: %.2f" % [body, height])
	model.position.y -= bounds.position.y
	animator.stop()
	rig.reset_bone_poses()
	var scene := PackedScene.new()
	assert(scene.pack(model) == OK)
	var intermediate := folder.path_join("%d-%s.scn" % [body, style])
	assert(ResourceSaver.save(scene, intermediate, ResourceSaver.FLAG_COMPRESS) == OK)
	var digest := FileAccess.get_sha256(intermediate)
	var target := folder.path_join("%d-%s-%s.scn" % [body, style, digest])
	if FileAccess.file_exists(target):
		assert(FileAccess.get_sha256(target) == digest)
		assert(DirAccess.remove_absolute(intermediate) == OK)
	else:
		assert(DirAccess.rename_absolute(intermediate, target) == OK)
	print("TER MUR MODEL ", body, " ", style, " ", rig.get_bone_count(), " bones, height ", height, " SHA256 ", digest)
	model.free()
	return digest


func skin_regions(mesh: MeshInstance3D, rig: Skeleton3D, body: int) -> Array[Dictionary]:
	var bindings := PackedInt32Array()
	for slot in mesh.skin.get_bind_count():
		var id := mesh.skin.get_bind_bone(slot)
		if id < 0:
			id = rig.find_bone(mesh.skin.get_bind_name(slot))
		bindings.append(region_for_bone(rig.get_bone_name(id), body))
	var result: Array[Dictionary] = []
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var triangles: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var stride := indices.size() / vertices.size()
		assert(stride in [4, 8] and triangles.size() % 3 == 0)
		var groups := {}
		for face in range(0, triangles.size(), 3):
			var totals := {}
			for corner in 3:
				for influence in stride:
					var offset := triangles[face + corner] * stride + influence
					var graphic := bindings[indices[offset]]
					totals[graphic] = float(totals.get(graphic, 0.0)) + weights[offset]
			var winner := 0
			var strongest := float(totals.get(0, 0.0))
			for graphic: int in totals:
				if totals[graphic] > strongest:
					winner = graphic
					strongest = totals[graphic]
			if not groups.has(winner):
				groups[winner] = PackedInt32Array()
			for corner in 3:
				groups[winner].append(triangles[face + corner])
		result.append(groups)
	return result


func region_for_bone(bone: String, body: int) -> int:
	if body in [666, 667]:
		if bone in ["bip01 spine1", "bip01 spine2", "bip01 l clavicle", "bip01 r clavicle"]:
			return 0x304
		if bone.ends_with("upperarm") or bone.ends_with("forearm"):
			return 0x301
		if bone in ["bip01 pelvis", "bip01 spine", "bip01 l thigh", "bip01 r thigh"]:
			return 0x311
		if bone.ends_with("calf"):
			return 0x40a
	elif body == 739:
		if bone in ["bip01 spine", "bip01 spine1", "bip01 pelvis", "bip01 neck"]:
			return 2
		if bone.ends_with("clavicle") or bone.ends_with("thigh") or bone.ends_with("upperarm"):
			return 1
	return 0


func add_vollem_flight(animator: AnimationPlayer) -> void:
	# The donor's running cycle has a continuous working wing stroke. Preserve
	# its wing tracks while replacing ground limb tracks with a tucked pose.
	var library := animator.get_animation_library("").duplicate(true) as AnimationLibrary
	animator.remove_animation_library("")
	animator.add_animation_library("", library)
	var motion := library.get_animation("Run").duplicate(true) as Animation
	var idle := library.get_animation("Idle")
	for track in range(motion.get_track_count() - 1, -1, -1):
		var path := motion.track_get_path(track)
		var bone := str(path.get_concatenated_subnames())
		if bone.begins_with("wing_"):
			continue
		var reference := idle.find_track(path, motion.track_get_type(track))
		if reference < 0 or idle.track_get_key_count(reference) == 0:
			continue
		var resting: Variant = idle.track_get_key_value(reference, 0)
		for key in motion.track_get_key_count(track):
			motion.track_set_key_value(track, key, resting)
	motion.loop_mode = Animation.LOOP_LINEAR
	assert(library.add_animation("Fly", motion) == OK)


func posture_gargoyle(animator: AnimationPlayer, rig: Skeleton3D) -> void:
	var library := animator.get_animation_library("").duplicate(true) as AnimationLibrary
	animator.remove_animation_library("")
	animator.add_animation_library("", library)
	for clip: String in ["Idle", "Walk", "Run", "Fidget"]:
		var animation := library.get_animation(clip)
		for side: String in ["l", "r"]:
			var wing := rig.find_bone("gargoyle " + side + " mainwing1")
			for track in animation.get_track_count():
				if animation.track_get_type(track) != Animation.TYPE_ROTATION_3D \
						or str(animation.track_get_path(track).get_concatenated_subnames()) != rig.get_bone_name(wing):
					continue
				animator.play(clip, 0.0)
				for key in animation.track_get_key_count(track):
					animator.seek(animation.track_get_key_time(track, key), true)
					animator.advance(0.0)
					rig.force_update_all_bone_transforms()
					var parent := rig.get_bone_global_pose(rig.get_bone_parent(wing)).basis.orthonormalized()
					var axis := parent.inverse() * Vector3.UP
					var rearward := Quaternion(axis.normalized(), .52 if side == "l" else -.52)
					var previous := animation.rotation_track_interpolate(track, animation.track_get_key_time(track, key))
					animation.track_set_key_value(track, key, (rearward * previous).normalized())
				var path := animation.track_get_path(track)
				var scale_track := animation.find_track(path, Animation.TYPE_SCALE_3D)
				if scale_track < 0:
					scale_track = animation.add_track(Animation.TYPE_SCALE_3D)
					animation.track_set_path(scale_track, path)
					animation.track_insert_key(scale_track, 0.0, Vector3.ONE)
				for key in animation.track_get_key_count(scale_track):
					var before: Vector3 = animation.track_get_key_value(scale_track, key)
					animation.track_set_key_value(scale_track, key, before * .78)
				break


func idle_pose(rig: Skeleton3D, animator: AnimationPlayer) -> void:
	animator.play("Idle", 0.0)
	animator.seek(0.0, true)
	animator.advance(0.0)
	rig.force_update_all_bone_transforms()


func add_gargoyle_equipment(model: Node3D, rig: Skeleton3D, animator: AnimationPlayer) -> void:
	idle_pose(rig, animator)
	var ring := TorusMesh.new()
	ring.inner_radius = .107
	ring.outer_radius = .137
	ring.rings = 32
	ring.ring_segments = 8
	ring.material = finish_material(Color("#9c8b6a"), .64, .24)
	attach(model, rig, "Cyclone", "cp_grasp_rhand", ring, Vector3(.01, -.03, .015), 0x901,
		Basis(Vector3.RIGHT, PI * .5))
	var ivory := finish_material(Color("#c3aa8d"), .79, .0)
	for layer in [11, 16]:
		var graphics := Appearance.MaleHorns + Appearance.FemaleHorns if layer == 11 else Appearance.FacialHorns
		for graphic: int in graphics:
			var fit: Array = HornStyle[graphic]
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(ivory)
			for count: int in int(fit[7]):
				build_horn(surface, fit, count)
			surface.index()
			surface.generate_normals()
			var geometry := surface.commit()
			var label := "Horn%02d%04x" % [layer, graphic]
			attach(model, rig, label, "bip01 head", geometry, Vector3.ZERO, graphic)
			var item := rig.get_node(label + "Socket/" + label)
			item.set_meta("ter_mur_layer", layer)
			item.set_meta("corpse_prop_keeps_material", true)


func build_horn(surface: SurfaceTool, fit: Array, count: int) -> void:
	var side := -1.0 if count % 2 else 1.0
	var extra := .65 if count >= 2 else 1.0
	var base := Vector3(side * float(fit[0]) * extra, fit[1], fit[2])
	var sweep := float(fit[3]) * side * extra
	var rise := float(fit[4]) * extra
	var curl := float(fit[5])
	if count >= 2:
		base.y += .039
		sweep *= .65
	var radius := float(fit[6]) * extra
	var rings: Array[PackedVector3Array] = []
	for station in range(13):
		var t := float(station) / 12.0
		var centre := base + Vector3(sweep * sin(t * 2.25), curl * t * t, rise * t)
		var axis := Vector3(sweep * 2.25 * cos(t * 2.25), curl * 2.0 * t, rise).normalized()
		var u := axis.cross(Vector3.FORWARD).normalized()
		if u.is_zero_approx():
			u = Vector3.RIGHT
		var v := axis.cross(u).normalized()
		var width := maxf(.00065, radius * pow(1.0 - t, .81))
		var ring := PackedVector3Array()
		for sector in 12:
			var angle := TAU * float(sector) / 12.0
			var flute := 1.0 + .048 * cos(angle * 4.0 + t * 8.0)
			ring.append(centre + (u * cos(angle) + v * sin(angle)) * width * flute)
		rings.append(ring)
	for i in 12:
		for j in 12:
			var next := (j + 1) % 12
			for corner in [Vector2i(i, j), Vector2i(i+1, j), Vector2i(i, next),
					Vector2i(i, next), Vector2i(i+1, j), Vector2i(i+1, next)]:
				surface.set_uv(Vector2(float(corner.y) / 12.0, float(corner.x) / 12.0))
				surface.add_vertex(rings[corner.x][corner.y])


func attach(model: Node3D, rig: Skeleton3D, label: String, bone: String, geometry: Mesh,
		offset: Vector3, item_id: int = 0, basis: Basis = Basis.IDENTITY) -> void:
	var index := rig.find_bone(bone)
	assert(index >= 0, bone)
	var socket := BoneAttachment3D.new()
	socket.name = label + "Socket"
	rig.add_child(socket)
	socket.bone_name = bone
	socket.owner = model
	var item := MeshInstance3D.new()
	item.name = label
	item.mesh = geometry
	socket.add_child(item)
	item.owner = model
	var pose := rig.get_bone_global_pose(index)
	item.transform = pose.affine_inverse() * Transform3D(basis, pose.origin + offset)
	if item_id:
		item.visible = false
		item.set_meta("ter_mur_equipment", item_id)
		item.set_meta("optional_corpse_visual_prop", true)


func finish_material(colour: Color, roughness: float, metalness: float) -> StandardMaterial3D:
	var finish := StandardMaterial3D.new()
	var image := Image.create_empty(64, 64, true, Image.FORMAT_RGB8)
	var grain := FastNoiseLite.new()
	grain.seed = 739
	grain.frequency = .22
	for y in 64:
		for x in 64:
			var value := .52 + grain.get_noise_2d(x, y) * .15
			image.set_pixel(x, y, Color(value, value, value))
	image.generate_mipmaps()
	finish.albedo_texture = ImageTexture.create_from_image(image)
	finish.albedo_color = colour
	finish.roughness = roughness
	finish.metallic = metalness
	finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	finish.set_meta("ter_mur_finish", true)
	return finish
