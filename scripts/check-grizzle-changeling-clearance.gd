# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Batch := preload("bake-grizzle-changeling-enhanced.gd")
const PosedSurface := preload("res://../scripts/ophidian-bardiche-clearance.gd")
const Rate := 240
const Head := ["bip01 head", "bip01 neck", "extrahead"]
const Core := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head"]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var report := {}
	for body: int in [259, 264]:
		var treatments := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var path := Batch.Destination + "%d-%s.scn" % [body, treatment]
			var model := (load(path) as PackedScene).instantiate()
			root.add_child(model)
			var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var mesh := model.find_child("Body", true, false) as MeshInstance3D
			var surface := PosedSurface.new(mesh, rig)
			var triangles := core_triangles(surface, rig, Head if body == 259 else Core)
			assert(not triangles.is_empty())
			player.play("Idle")
			player.advance(0.0)
			rig.force_update_all_bone_transforms()
			surface.update_pose()
			var wings := []
			var hands := []
			for side: String in ["l", "r"]:
				if body == 259:
					var wrist := rig.find_bone("bip01 %s hand" % side)
					var fingers := rig.get_bone_children(wrist)
					assert(not fingers.is_empty())
					hands.append({"wrist": wrist, "fingers": fingers})
				else:
					var label := "bone_wingleft" if side == "l" else "bone_wingright"
					wings.append(wing_witness(surface, rig, label))
			var clips: Dictionary = Batch.Grizzle if body == 259 else Batch.Changeling
			var checked := {}
			for clip: String in clips.values():
				checked[clip] = measure(player, rig, surface, triangles, hands, wings, clip)
				print("GRIZZLE AND CHANGELING GEOMETRY ", body, "/", treatment, "/", clip, ": ", checked[clip])
			treatments[treatment] = {"scene_sha256": FileAccess.get_sha256(path), "core_triangles": triangles.size(), "clips": checked}
			model.free()
		report[str(body)] = treatments
	var file := FileAccess.open(Batch.Destination + "dense-clearance-receipt.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"sample_rate": Rate, "bodies": report}, "\t"))
	file.close()
	quit()


func core_triangles(surface: RefCounted, rig: Skeleton3D, labels: Array) -> PackedInt32Array:
	var core := PackedByteArray()
	for vertex in surface.positions.size():
		var weight := 0.0
		for influence in surface.stride:
			var slot: int = vertex * surface.stride + influence
			if rig.get_bone_name(surface.bones[surface.joints[slot]]) in labels:
				weight += surface.weights[slot]
		core.append(1 if weight > .70 else 0)
	var indices := PackedInt32Array()
	for triangle in surface.bounds.size():
		var offset: int = triangle * 3
		if core[surface.indices[offset]] and core[surface.indices[offset + 1]] and core[surface.indices[offset + 2]]:
			indices.append(triangle)
	return indices


func wing_witness(surface: RefCounted, rig: Skeleton3D, label: String) -> Dictionary:
	var bone := rig.find_bone(label)
	var pivot := joint_position(rig, bone)
	var candidates := []
	for vertex in surface.positions.size():
		for influence in surface.stride:
			var slot: int = vertex * surface.stride + influence
			if surface.bones[surface.joints[slot]] == bone and surface.weights[slot] > .90:
				var point: Vector3 = surface.deformed[vertex]
				candidates.append({"distance": point.distance_to(pivot), "point": point, "vertex": vertex})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return a.distance > b.distance)
	var chosen := PackedInt32Array()
	var points := PackedVector3Array()
	for candidate: Dictionary in candidates:
		var distinct := true
		for point: Vector3 in points:
			if point.distance_to(candidate.point) < .10:
				distinct = false
				break
		if distinct:
			points.append(candidate.point)
			chosen.append(candidate.vertex)
			if chosen.size() == 8:
				break
	assert(chosen.size() >= 4)
	return {"bone": bone, "tips": chosen}


func measure(player: AnimationPlayer, rig: Skeleton3D, surface: RefCounted, triangles: PackedInt32Array,
		hands: Array, wings: Array, clip: String) -> Dictionary:
	player.play(clip, 0.0)
	player.advance(0.0)
	var intervals := ceili(player.current_animation_length * Rate)
	var crossings := 0
	var first_crossing := -1.0
	var last_crossing := -1.0
	var floor_minimum := INF
	var floor_peak := -INF
	var wing_span := 0.0
	for sample in intervals + 1:
		var phase := float(sample) / intervals
		player.seek(player.current_animation_length * phase, true)
		rig.force_update_all_bone_transforms()
		surface.update_pose()
		var floor := INF
		for point: Vector3 in surface.deformed:
			floor = minf(floor, point.y)
		floor_minimum = minf(floor_minimum, floor)
		floor_peak = maxf(floor_peak, floor)
		var crossed := false
		for hand: Dictionary in hands:
			var wrist := joint_position(rig, hand.wrist)
			for finger: int in hand.fingers:
				crossed = crosses(surface, triangles, wrist, joint_position(rig, finger)) or crossed
		for wing: Dictionary in wings:
			var root_point := joint_position(rig, wing.bone)
			for index: int in wing.tips:
				var tip: Vector3 = surface.deformed[index]
				wing_span = maxf(wing_span, root_point.distance_to(tip))
				crossed = crosses(surface, triangles, root_point.lerp(tip, .48), tip) or crossed
		if crossed:
			crossings += 1
			if first_crossing < 0.0:
				first_crossing = phase
			last_crossing = phase
	return {"samples": intervals + 1, "crossings": crossings, "first_crossing": first_crossing,
		"last_crossing": last_crossing, "floor_minimum": floor_minimum, "floor_peak": floor_peak, "wing_span": wing_span}


func joint_position(rig: Skeleton3D, bone: int) -> Vector3:
	return rig.to_global(rig.get_bone_global_pose(bone).origin)


func crosses(surface: RefCounted, triangles: PackedInt32Array, start: Vector3, finish: Vector3) -> bool:
	var limits := AABB(start, Vector3.ZERO).expand(finish).grow(.001)
	for triangle: int in triangles:
		if not limits.intersects(surface.bounds[triangle]):
			continue
		var i := triangle * 3
		if Geometry3D.segment_intersects_triangle(start, finish, surface.deformed[surface.indices[i]],
				surface.deformed[surface.indices[i + 1]], surface.deformed[surface.indices[i + 2]]) != null:
			return true
	return false
