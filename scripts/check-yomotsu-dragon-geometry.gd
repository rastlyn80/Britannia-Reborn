# SPDX-License-Identifier: GPL-3.0-or-later
extends "bake-yomotsu-warrior-dragon-enhanced.gd"


func run() -> void:
	var proof := {}
	for treatment: String in ["original", "rounded", "modern"]:
		proof[treatment] = {"warrior": verify_warrior(treatment), "dragon": verify_dragon(treatment)}
		print("YOMOTSU AND DRAGON GEOMETRY ", treatment, " ", proof[treatment])
	var receipt := FileAccess.open(Destination + "geometry-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify(proof, "\t"))
	receipt.close()
	quit()


func verify_warrior(treatment: String) -> Dictionary:
	var source := Registry.asset_path(Registry.entry(245), treatment)
	var target := Destination + "245-%s.scn" % treatment
	var original := (load(source) as PackedScene).instantiate()
	var fitted := (load(target) as PackedScene).instantiate()
	var original_mesh := original.find_child("Body", true, false) as MeshInstance3D
	var body := fitted.find_child("Body", true, false) as MeshInstance3D
	var blade := fitted.find_child("YomotsuBlade", true, false) as MeshInstance3D
	var before := triangle_counts(original_mesh)
	var after := triangle_counts(body)
	var blade_triangles := triangle_counts(blade)
	for triangle: Array in blade_triangles:
		after[triangle] = int(after.get(triangle, 0)) + int(blade_triangles[triangle])
	assert(before == after, "The partition must conserve triangles, UVs and skin influences")
	var body_count: int = body.mesh.surface_get_array_index_len(0) / 3
	var blade_count: int = blade.mesh.surface_get_array_index_len(0) / 3
	assert(blade.transform == body.transform and blade.skeleton == body.skeleton and blade.skin == body.skin)
	original.free()
	fitted.free()
	return {"scene_sha256": FileAccess.get_sha256(target), "source_sha256": FileAccess.get_sha256(source),
		"blade_triangles": blade_count, "body_triangles": body_count}


func triangle_counts(node: MeshInstance3D) -> Dictionary:
	var arrays := node.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var stride := bones.size() / points.size()
	var counts := {}
	for corner in range(0, indices.size(), 3):
		var triangle := []
		for vertex in indices.slice(corner, corner + 3):
			triangle.append([points[vertex], uv[vertex], bones.slice(vertex * stride, (vertex + 1) * stride),
				weights.slice(vertex * stride, (vertex + 1) * stride)])
		counts[triangle] = int(counts.get(triangle, 0)) + 1
	return counts


func verify_dragon(treatment: String) -> Dictionary:
	var target := Destination + "59-%s.scn" % treatment
	var model := (load(target) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var wings: Array = []
	var lengths := PackedFloat32Array()
	for chain: Array in WingChains:
		var joints: Array = chain.map(func(label: String): return rig.find_bone(label))
		wings.append(joints)
		for i in range(1, joints.size()):
			var a := rig.get_bone_global_rest(joints[i - 1]).origin
			var b := rig.get_bone_global_rest(joints[i]).origin
			lengths.append(a.distance_to(b))
	var clips := {}
	for group: int in DragonClips:
		var name: String = DragonClips[group]
		player.stop()
		player.play(name, 0.0)
		player.advance(0.0)
		var intervals := ceili(player.current_animation_length * 480.0)
		var max_drift := 0.0
		var tip_step := 0.0
		var min_width := INF
		var max_width := 0.0
		var previous_tips := PackedVector3Array()
		for step in intervals + 1:
			player.seek(player.current_animation_length * step / intervals, true)
			rig.force_update_all_bone_transforms()
			var tips := PackedVector3Array()
			var link := 0
			for chain: Array in wings:
				var previous := rig.get_bone_global_pose(chain[0]).origin
				for i in range(1, chain.size()):
					var point := rig.get_bone_global_pose(chain[i]).origin
					max_drift = maxf(max_drift, absf(previous.distance_to(point) - lengths[link]))
					previous = point
					link += 1
				tips.append(rig.to_global(previous))
			for side in previous_tips.size():
				tip_step = maxf(tip_step, tips[side].distance_to(previous_tips[side]))
			previous_tips = tips
			var width := absf(tips[0].x - tips[1].x)
			min_width = minf(min_width, width)
			max_width = maxf(max_width, width)
		assert(max_drift < .00005 and tip_step < .14)
		if group == 23:
			assert(max_width >= min_width * 1.45)
		clips[name] = {"poses": intervals + 1, "max_drift": max_drift, "tip_step": tip_step,
			"min_width": min_width, "max_width": max_width}
	model.free()
	return {"scene_sha256": FileAccess.get_sha256(target), "clips": clips}
