# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-giant-spider-actions.gd"

const DonorBody := 157
const Styles := ["original", "rounded", "modern"]
const Clips := {
	2: ["Death", .90], 3: ["Death2", 1.0], 4: ["NavreySnap", .6], 5: ["NavreyRearingStrike", 1.0],
	10: ["Hit", .70], 15: ["NavreyBrace", .70], 19: ["NavreySilkLift", 1.30],
	23: ["NavreySilkDescent", 1.0], 25: ["ReadyStance", 1.10], 26: ["NavreyWatch", 1.0],
	27: ["NavreyAbdomenRears", 1.0], 28: ["NavreyAlert", .60],
}


func run() -> void:
	var folder := OS.get_environment("BR_NAVREY_OUTPUT")
	assert(not folder.is_empty() and DirAccess.dir_exists_absolute(folder))
	var row := Registry.entry(DonorBody)
	assert(row.kind == "arachnids_spider_black_widow")
	var scenes := {}
	for style: String in Styles:
		var source := Registry.asset_path(row, style)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[style])
		var model := (load(source) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var animator := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var measurements := reshape(mesh)
		model.scale *= Vector3(1.55, 1.46, 1.59)
		var skin := Ground.skin_points(mesh, rig)
		var library := animator.get_animation_library("").duplicate(true) as AnimationLibrary
		animator.remove_animation_library("")
		animator.add_animation_library("", library)
		animator.deterministic = true
		for name: String in ["Idle", "Walk", "Run"]:
			var grounded := ground_locomotion(animator, rig, skin, name)
			library.remove_animation(name)
			assert(library.add_animation(name, grounded) == OK)
		for group: int in Clips:
			var descriptor: Array = Clips[group]
			var clip := fit(animator, rig, skin, group, descriptor[1])
			if library.has_animation(descriptor[0]):
				library.remove_animation(descriptor[0])
			assert(library.add_animation(descriptor[0], clip) == OK)
		var aliases := {"Attack": "NavreySnap", "Fidget": "NavreyWatch", "NavreyPeaceWalk": "Walk"}
		for name: String in aliases:
			if library.has_animation(name):
				library.remove_animation(name)
			assert(library.add_animation(name, library.get_animation(aliases[name])) == OK)
		animator.stop()
		rig.reset_bone_poses()
		var result := PackedScene.new()
		var target := folder.path_join("735-%s.scn" % style)
		assert(result.pack(model) == OK and ResourceSaver.save(result, target, ResourceSaver.FLAG_COMPRESS) == OK)
		scenes[style] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(target),
			"meshes": measurements, "bones": rig.get_bone_count(), "clips": animator.get_animation_list()}
		model.free()
		print("NAVREY FIT: ", style, " / ", scenes[style].bones, " bones / ", measurements.changed_vertices, " changed vertices")
	var receipt := FileAccess.open(folder.path_join("fitted-scenes.json"), FileAccess.WRITE)
	receipt.store_string(JSON.stringify(scenes, "\t"))
	receipt.close()
	quit()


func ground_locomotion(animator: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, name: String) -> Animation:
	var clip := animator.get_animation(name).duplicate(true) as Animation
	var root_bone := rig.find_bone("bone01")
	var rig_path := animator.get_node(animator.root_node).get_path_to(rig)
	var path := NodePath(str(rig_path) + ":bone01")
	var track := clip.find_track(path, Animation.TYPE_POSITION_3D)
	if track < 0:
		track = clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(track, path)
	for key in range(clip.track_get_key_count(track) - 1, -1, -1):
		clip.track_remove_key(track, key)
	animator.play(name, 0.0)
	animator.advance(0.0)
	for frame in 97:
		var at := clip.length * float(frame) / 96.0
		animator.seek(at, true)
		rig.force_update_all_bone_transforms()
		var pose := rig.get_bone_global_pose(root_bone)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		pose.origin += rig.global_basis.inverse() * Vector3.UP * (.004 - gap)
		rig.set_bone_global_pose(root_bone, pose)
		clip.position_track_insert_key(track, at, rig.get_bone_pose_position(root_bone))
	animator.stop()
	rig.reset_bone_poses()
	return clip


func reshape(mesh: MeshInstance3D) -> Dictionary:
	var original := mesh.mesh
	var reshaped := ArrayMesh.new()
	var changed := 0
	var preserved := 0
	for surface in original.get_surface_count():
		var arrays := original.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var bindings: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var stride := weights.size() / points.size()
		for index in points.size():
			var abdomen := 0.0
			for slot in stride:
				var offset := index * stride + slot
				if mesh.skin.get_bind_name(bindings[offset]) == "bone02":
					abdomen += weights[offset]
			var point := points[index]
			var swelling := smoothstep(.22, .58, point.y) * (smoothstep(.06, .65, abdomen) if abdomen > .0 else .0)
			if swelling <= .001:
				preserved += 1
				continue
			var centre := Vector3(-.001, .59, .69)
			var radial := point - centre
			var radius := Vector3(.46, .59, .55)
			var direction := (radial / radius).normalized()
			var shell := centre + direction * radius
			points[index] = point.lerp(shell, .82 * swelling)
			normals[index] = normals[index].lerp((direction / radius).normalized(), .78 * swelling).normalized()
			if not tangents.is_empty():
				var i := index * 4
				var tangent := Vector3(tangents[i], tangents[i + 1], tangents[i + 2])
				tangent = (tangent - normals[index] * tangent.dot(normals[index])).normalized()
				tangents[i] = tangent.x
				tangents[i + 1] = tangent.y
				tangents[i + 2] = tangent.z
			changed += 1
		arrays[Mesh.ARRAY_VERTEX] = points
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = tangents
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if stride == 8 else 0
		reshaped.add_surface_from_arrays(original.surface_get_primitive_type(surface), arrays, [], {}, flags)
		var material := original.surface_get_material(surface).duplicate() as StandardMaterial3D
		material.albedo_texture = chestnut_atlas(material.albedo_texture)
		reshaped.surface_set_material(surface, material)
	mesh.mesh = reshaped
	return {"changed_vertices": changed, "preserved_vertices": preserved, "bounds": str(reshaped.get_aabb())}


func chestnut_atlas(input: Texture2D) -> ImageTexture:
	var atlas := input.get_image()
	if atlas.is_compressed():
		assert(atlas.decompress() == OK)
	atlas.convert(Image.FORMAT_RGBA8)
	for y in atlas.get_height():
		for x in atlas.get_width():
			var colour := atlas.get_pixel(x, y)
			var light := colour.get_luminance()
			var red := maxf(0.0, colour.r - colour.g)
			var tone := lerpf(light, smoothstep(.04, .76, light), .34)
			atlas.set_pixel(x, y, Color(tone * .86 + red * .19, tone * .50, tone * .36, colour.a))
	atlas.generate_mipmaps()
	return ImageTexture.create_from_image(atlas)


func pose(rig: Skeleton3D, slot: int, phase: float) -> void:
	var accent := smoothstep(.08, .37, phase) * (1.0 - smoothstep(.56, .96, phase))
	var death := smoothstep(.15, .87, phase) if slot in [2, 3] else 0.0
	var slam := accent if slot == 4 else 0.0
	var rise := accent if slot in [5, 27] else 0.0
	var withdraw := accent if slot in [10, 15] else 0.0
	var silk := smoothstep(.08, .80, phase) if slot == 19 else 1.0 - smoothstep(.18, .88, phase) if slot == 23 else 0.0
	var alert := accent if slot == 28 else 0.0
	var watch := sin(phase * TAU) * .07 if slot in [25, 26] else 0.0
	var roll := (1.50 if slot == 3 else -.51) * death
	turn(rig, "bone01", Vector3.FORWARD, roll)
	turn(rig, "bone01", Vector3.RIGHT, .30 * slam - .28 * rise + .19 * withdraw - .32 * silk + .12 * alert + watch)
	turn(rig, "bone02", Vector3.RIGHT, -.33 * slam - .65 * rise - .70 * silk + .19 * death - .25 * alert + watch)
	for index in LEGS.size():
		var pair: Array = LEGS[index]
		var side := 1.0 if index % 2 == 0 else -1.0
		var front := 1.0 if index < 4 else .22
		var curl := (.66 if slot == 3 else .39) * death
		turn(rig, pair[0], Vector3.UP, side * (curl + .42 * slam * front - .29 * withdraw + watch))
		turn(rig, pair[0], Vector3.RIGHT, -.57 * rise * front - .63 * slam * front + .20 * silk + .25 * alert)
		turn(rig, pair[1], Vector3.FORWARD, side * (-.86 * curl + .38 * slam * front + .31 * withdraw))
