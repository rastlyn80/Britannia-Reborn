# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Bake := preload("bake-terathan-avenger-enhanced.gd")
const PosedSurface := preload("res://../scripts/ophidian-bardiche-clearance.gd")
const Rate := 240


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var treatments := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var path := Bake.Destination + "152-%s.scn" % treatment
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var surface := PosedSurface.new(model.find_child("Body", true, false), rig)
		var core := core_triangles(surface, rig)
		assert(not core.is_empty())
		var reports := {}
		for clip: String in Bake.Clips.values():
			reports[clip] = measure(player, rig, surface, core, clip)
			print("AVENGER PINCER ", treatment, "/", clip, ": ", reports[clip])
		treatments[treatment] = {"scene_sha256": FileAccess.get_sha256(path), "clips": reports}
		model.free()
	var receipt := FileAccess.open(Bake.Destination + "avenger-pincer-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"sample_rate": Rate, "treatments": treatments}, "\t"))
	receipt.close()
	quit()


func core_triangles(surface: RefCounted, rig: Skeleton3D) -> PackedInt32Array:
	var arm_bones := {}
	for side: String in ["l", "r"]:
		for part: String in ["clavicle", "upperarm", "forearm", "hand"]:
			arm_bones[rig.find_bone("bip01 %s %s" % [side, part])] = true
	var core := PackedByteArray()
	for vertex in surface.positions.size():
		var arm_weight := 0.0
		for index in surface.stride:
			var slot: int = vertex * surface.stride + index
			if arm_bones.has(surface.bones[surface.joints[slot]]):
				arm_weight += surface.weights[slot]
		core.append(1 if arm_weight < .25 else 0)
	var triangles := PackedInt32Array()
	for triangle in surface.bounds.size():
		var start: int = triangle * 3
		if core[surface.indices[start]] and core[surface.indices[start + 1]] and core[surface.indices[start + 2]]:
			triangles.append(triangle)
	return triangles


func measure(player: AnimationPlayer, rig: Skeleton3D, surface: RefCounted, core: PackedInt32Array, clip: String) -> Dictionary:
	player.play(clip, 0.0)
	player.advance(0.0)
	var intervals := ceili(player.current_animation_length * Rate)
	var crossings := PackedFloat32Array()
	var nearest := INF
	var floor_gap := INF
	var maximum_gap := -INF
	for sample in intervals + 1:
		var phase := float(sample) / intervals
		player.seek(player.current_animation_length * phase, true)
		rig.force_update_all_bone_transforms()
		surface.update_pose()
		var gap := INF
		for vertex: Vector3 in surface.deformed:
			gap = minf(gap, vertex.y)
		floor_gap = minf(floor_gap, gap)
		maximum_gap = maxf(maximum_gap, gap)
		var left := pincer_segment(rig, "l")
		var right := pincer_segment(rig, "r")
		var points := Geometry3D.get_closest_points_between_segments(left[0], left[1], right[0], right[1])
		nearest = minf(nearest, points[0].distance_to(points[1]))
		if crosses_core(surface, core, left) or crosses_core(surface, core, right):
			crossings.append(phase)
	return {"samples": intervals + 1, "floor_gap": floor_gap, "maximum_gap": maximum_gap,
		"pincer_centreline_separation": nearest, "core_crossings": crossings.size(),
		"first_crossing": -1.0 if crossings.is_empty() else crossings[0],
		"last_crossing": -1.0 if crossings.is_empty() else crossings[-1]}


func pincer_segment(rig: Skeleton3D, side: String) -> PackedVector3Array:
	var hand := rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 %s hand" % side)).origin)
	var tip := rig.to_global(rig.get_bone_global_pose(rig.find_bone("cp_grasp_%shand" % side)).origin)
	return PackedVector3Array([hand.lerp(tip, .14), tip])


func crosses_core(surface: RefCounted, core: PackedInt32Array, line: PackedVector3Array) -> bool:
	var limits := AABB(line[0], Vector3.ZERO).expand(line[1]).grow(.001)
	for triangle: int in core:
		if not limits.intersects(surface.bounds[triangle]):
			continue
		var i := triangle * 3
		if Geometry3D.segment_intersects_triangle(line[0], line[1], surface.deformed[surface.indices[i]],
				surface.deformed[surface.indices[i + 1]], surface.deformed[surface.indices[i + 2]]) != null:
			return true
	return false
