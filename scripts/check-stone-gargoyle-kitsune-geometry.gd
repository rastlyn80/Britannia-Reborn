# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Batch := preload("bake-stone-gargoyle-kitsune-enhanced.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Surface := preload("res://../scripts/ophidian-bardiche-clearance.gd")
const Rate := 240
const StoneLinks := [["gargoyle l mainwing1", "gargoyle l mainwing2", "gargoyle l wing4"],
	["gargoyle r mainwing1", "gargoyle r mainwing2", "gargoyle r wing4"]]
const TailLinks := [["bip01 tail", "bip01 tail1", "bip01 tailnub"],
	["l_tailbone", "l_tailbone01"], ["m_tailbone", "m_tailbone01"]]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var bodies := {}
	var failed := false
	for body: int in [67, 246]:
		var treatments := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var path := Batch.Destination + "%d-%s.scn" % [body, treatment]
			var model := (load(path) as PackedScene).instantiate()
			root.add_child(model)
			var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var mesh := model.find_child("Body", true, false) as MeshInstance3D
			var skin := Ground.skin_points(mesh, rig)
			var surface := Surface.new(mesh, rig)
			var wings := dominant_wing_points(surface, rig) if body == 67 else PackedInt32Array()
			var paws := dominant_paw_points(surface, rig, body)
			var results := {}
			var clips := Batch.Stone if body == 67 else Batch.Kitsune
			for group: int in clips:
				var result := measure(rig, player, skin, surface, wings, paws, clips[group], body)
				results[clips[group]] = result
				failed = failed or result.floor_minimum < .0025 or result.link_error > .0005 or result.link_drift > .000015
				failed = failed or result.maximum_tip_step > .10
				print("STONE AND KITSUNE GEOMETRY ", body, "/", treatment, "/", group, " ", result)
			treatments[treatment] = {"scene_sha256": FileAccess.get_sha256(path), "clips": results}
			model.free()
		bodies[str(body)] = treatments
	var receipt := FileAccess.open(Batch.Destination + "dense-geometry-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"sample_rate": Rate, "passed": not failed, "bodies": bodies}, "\t"))
	receipt.close()
	quit(1 if failed else 0)


func dominant_wing_points(surface: RefCounted, rig: Skeleton3D) -> PackedInt32Array:
	var result := PackedInt32Array()
	for vertex in surface.positions.size():
		var total := 0.0
		for index in surface.stride:
			var slot: int = vertex * surface.stride + index
			var joint := rig.get_bone_name(surface.bones[surface.joints[slot]])
			if joint.begins_with("gargoyle l ") or joint.begins_with("gargoyle r "):
				total += surface.weights[slot]
		if total > .86:
			result.append(vertex)
	assert(not result.is_empty())
	return result


func dominant_paw_points(surface: RefCounted, rig: Skeleton3D, body: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for vertex in surface.positions.size():
		var total := 0.0
		for index in surface.stride:
			var slot: int = vertex * surface.stride + index
			var joint := rig.get_bone_name(surface.bones[surface.joints[slot]])
			if " toe" in joint or joint.ends_with(" foot") or (body == 246 and joint.ends_with(" hand")):
				total += surface.weights[slot]
		if total > .72:
			result.append(vertex)
	assert(not result.is_empty())
	return result


func measure(rig: Skeleton3D, player: AnimationPlayer, skin: Dictionary, surface: RefCounted,
		wings: PackedInt32Array, paws: PackedInt32Array, clip: String, body: int) -> Dictionary:
	player.stop()
	var back := rig.find_bone("wing_connector")
	var forward_in_back := Vector3.ZERO
	if body == 67:
		player.play("Idle", 0.0)
		player.advance(0.0)
		rig.force_update_all_bone_transforms()
		var basis := rig.global_basis * rig.get_bone_global_pose(back).basis
		forward_in_back = (basis.inverse() * Vector3.BACK).normalized()
		player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var intervals := ceili(player.current_animation_length * Rate)
	var paths := StoneLinks if body == 67 else TailLinks
	var joints: Array[PackedInt32Array] = []
	var lengths := PackedFloat32Array()
	var first_lengths := PackedFloat32Array()
	for path: Array in paths:
		var chain := PackedInt32Array()
		for name: String in path:
			var joint := rig.find_bone(name)
			assert(joint >= 0)
			chain.append(joint)
		joints.append(chain)
		for index in range(1, chain.size()):
			var delta := rig.get_bone_global_rest(chain[index]).origin - rig.get_bone_global_rest(chain[index - 1]).origin
			lengths.append((rig.global_basis * delta).length())
	var result := {"samples": intervals + 1, "floor_minimum": INF, "link_error": 0.0, "link_drift": 0.0,
		"maximum_tip_step": 0.0, "minimum_tip_span": INF, "maximum_tip_span": 0.0, "maximum_paw_clearance": 0.0,
		"maximum_wing_depth_relative_to_back": -INF, "floor_joint_at_maximum_paw_gap": ""}
	var previous := PackedVector3Array()
	for sample in intervals + 1:
		player.seek(player.current_animation_length * sample / intervals, true)
		rig.force_update_all_bone_transforms()
		var floor := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		result.floor_minimum = minf(result.floor_minimum, floor)
		surface.update_pose()
		var paw_height := INF
		for vertex in paws:
			paw_height = minf(paw_height, (surface.deformed[vertex] as Vector3).y)
		if paw_height > result.maximum_paw_clearance:
			result.maximum_paw_clearance = paw_height
			var lowest := INF
			var floor_vertex := 0
			for vertex in surface.deformed.size():
				var point: Vector3 = surface.deformed[vertex]
				if point.y < lowest:
					lowest = point.y
					floor_vertex = vertex
			var strongest := 0.0
			for index in surface.stride:
				var slot: int = floor_vertex * surface.stride + index
				var weight: float = surface.weights[slot]
				if weight > strongest:
					strongest = weight
					result.floor_joint_at_maximum_paw_gap = rig.get_bone_name(surface.bones[surface.joints[slot]])
		var tips := PackedVector3Array()
		var length_index := 0
		for chain: PackedInt32Array in joints:
			for index in range(1, chain.size()):
				var a := rig.to_global(rig.get_bone_global_pose(chain[index - 1]).origin)
				var b := rig.to_global(rig.get_bone_global_pose(chain[index]).origin)
				var length := a.distance_to(b)
				result.link_error = maxf(result.link_error, absf(length - lengths[length_index]))
				if sample == 0:
					first_lengths.append(length)
				else:
					result.link_drift = maxf(result.link_drift, absf(length - first_lengths[length_index]))
				length_index += 1
			tips.append(rig.to_global(rig.get_bone_global_pose(chain[-1]).origin))
		var span := tips[0].distance_to(tips[-1])
		result.minimum_tip_span = minf(result.minimum_tip_span, span)
		result.maximum_tip_span = maxf(result.maximum_tip_span, span)
		for index in previous.size():
			result.maximum_tip_step = maxf(result.maximum_tip_step, tips[index].distance_to(previous[index]))
		previous = tips
		if body == 67:
			var anchor := rig.global_transform * rig.get_bone_global_pose(back)
			var forward := (anchor.basis * forward_in_back).normalized()
			for vertex in wings:
				var point: Vector3 = surface.deformed[vertex]
				result.maximum_wing_depth_relative_to_back = maxf(result.maximum_wing_depth_relative_to_back,
					forward.dot(point - anchor.origin))
	if body != 67:
		result.erase("maximum_wing_depth_relative_to_back")
	return result
