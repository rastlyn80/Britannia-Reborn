# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/check-grizzle-changeling-clearance.gd"

const Lord := preload("bake-juka-lord-enhanced.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Torso := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head"]


func run() -> void:
	var report := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var row := Registry.entry(766).duplicate(true)
		for name: String in row.assets:
			row.assets[name] = Lord.Destination + "766-%s.scn" % name
		var actor := Registry.create(766)
		actor.entry = row
		actor.treatment = treatment
		root.add_child(actor)
		actor.apply_identity(766, 0x455)
		actor.set_physics_process(false)
		actor.set_process(false)
		actor.set_equipment([{"id": 0x13b2, "layer": 2, "hue": 0}])
		assert(is_instance_valid(actor.bow_mesh) and actor.bow_mesh.is_visible_in_tree())
		var rig: Skeleton3D = actor.skeleton
		var mesh := actor.model.find_child("Body", true, false) as MeshInstance3D
		var posed := PosedSurface.new(mesh, rig)
		var triangles := core_triangles(posed, rig, Torso)
		assert(not triangles.is_empty())
		var local_vertices: PackedVector3Array = actor.rest_arrays[Mesh.ARRAY_VERTEX]
		var edges := bow_edges(actor.rest_arrays, local_vertices.size())
		var clips := {}
		for clip: String in Lord.LordClips.values():
			clips[clip] = measure_bow(actor, posed, triangles, local_vertices, edges, clip)
			print("JUKA LORD BOW ", treatment, "/", clip, " ", clips[clip])
		actor.set_equipment([])
		assert(not actor.bow_holder.visible)
		report[treatment] = {"scene_sha256": FileAccess.get_sha256(row.assets[treatment]), "clips": clips}
		actor.free()
	var receipt := FileAccess.open(Lord.Destination + "bow-clearance-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"sample_rate": Rate, "treatments": report}, "\t"))
	receipt.close()
	quit()


func bow_edges(arrays: Array, count: int) -> Array[Vector2i]:
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for index in count:
			indices.append(index)
	var unique := {}
	for offset in range(0, indices.size(), 3):
		for side in 3:
			var left := indices[offset + side]
			var right := indices[offset + (side + 1) % 3]
			unique[Vector2i(mini(left, right), maxi(left, right))] = true
	var edges: Array[Vector2i] = []
	edges.assign(unique.keys())
	return edges


func measure_bow(actor: Node3D, posed: RefCounted, triangles: PackedInt32Array, vertices: PackedVector3Array,
		edges: Array[Vector2i], clip: String) -> Dictionary:
	var player: AnimationPlayer = actor.animator
	actor.current_clip = clip
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var intervals := ceili(player.current_animation_length * Rate)
	var crossings := 0
	var clearance := INF
	var grip_error := 0.0
	for sample in intervals + 1:
		player.seek(player.current_animation_length * sample / intervals, true)
		actor.skeleton.force_update_all_bone_transforms()
		actor.update_bow()
		posed.update_pose()
		var grip := joint_position(actor.skeleton, actor.left_grasp)
		grip_error = maxf(grip_error, grip.distance_to(actor.bow_holder.global_position))
		var points := PackedVector3Array()
		for point: Vector3 in vertices:
			var world: Vector3 = actor.bow_mesh.to_global(point)
			clearance = minf(clearance, world.y)
			points.append(world)
		for edge: Vector2i in edges:
			if crosses(posed, triangles, points[edge.x], points[edge.y]):
				crossings += 1
				break
	return {"samples": intervals + 1, "crossings": crossings, "minimum_bow_height": clearance,
		"maximum_grip_error": grip_error}
