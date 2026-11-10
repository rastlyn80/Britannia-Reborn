# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Batch := preload("bake-matriarch-succubus-enhanced.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")
const Surface := preload("res://../scripts/ophidian-bardiche-clearance.gd")
const Rate := 240


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var reports := {}
	var failed := false
	for treatment: String in ["original", "rounded", "modern"]:
		var path := Batch.Destination + "149-%s.scn" % treatment
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var body := model.find_child("Body", true, false) as MeshInstance3D
		var surface := Surface.new(body, rig)
		var wings: Array[PackedInt32Array] = []
		var lengths := PackedFloat32Array()
		for side: String in ["l", "r"]:
			var chain := PackedInt32Array()
			for name: String in Batch.Wing[side]:
				var joint := rig.find_bone(name)
				assert(joint >= 0)
				chain.append(joint)
			wings.append(chain)
			for index in range(1, chain.size()):
				lengths.append(rig.get_bone_global_rest(chain[index - 1]).origin.distance_to(
					rig.get_bone_global_rest(chain[index]).origin))
		var core := core_triangles(surface, wings)
		var clips := {}
		for clip: String in Batch.Succubus.values():
			player.stop()
			player.play(clip, 0.0)
			player.advance(0.0)
			var intervals := ceili(player.current_animation_length * Rate)
			var max_link_error := 0.0
			var max_tip_step := 0.0
			var previous := PackedVector3Array()
			var crossings := PackedFloat32Array()
			var min_span := INF
			var max_span := 0.0
			for sample in intervals + 1:
				var phase := float(sample) / intervals
				player.seek(phase * player.current_animation_length, true)
				rig.force_update_all_bone_transforms()
				surface.update_pose()
				var tips := PackedVector3Array()
				var crossed := false
				for side in wings.size():
					var chain := wings[side]
					for index in range(1, chain.size()):
						var a := rig.get_bone_global_pose(chain[index - 1]).origin
						var b := rig.get_bone_global_pose(chain[index]).origin
						max_link_error = maxf(max_link_error, absf(a.distance_to(b) - lengths[side * 2 + index - 1]))
						# The proximal joint is attached inside the back. Test the distal link outside the socket.
						if index == 2 and crosses_core(surface, core, rig.to_global(a), rig.to_global(b)):
							crossed = true
					tips.append(rig.to_global(rig.get_bone_global_pose(chain[-1]).origin))
				if crossed:
					crossings.append(phase)
				var span := tips[0].distance_to(tips[1])
				min_span = minf(min_span, span)
				max_span = maxf(max_span, span)
				for side in previous.size():
					max_tip_step = maxf(max_tip_step, previous[side].distance_to(tips[side]))
				previous = tips
			var widths := PackedFloat32Array()
			for phase: float in [0.0, .25, .5, .75, 1.0]:
				player.seek(player.current_animation_length * phase, true)
				rig.force_update_all_bone_transforms()
				widths.append(Geometry.deformed_bounds(body, rig).size.x)
			clips[clip] = {"samples": intervals + 1, "maximum_link_error_m": max_link_error,
				"maximum_tip_step_m": max_tip_step, "minimum_tip_span_m": min_span, "maximum_tip_span_m": max_span,
				"mesh_widths_m": Array(widths), "distal_core_crossings": crossings.size(),
				"first_crossing_phase": -1.0 if crossings.is_empty() else crossings[0],
				"last_crossing_phase": -1.0 if crossings.is_empty() else crossings[-1]}
			failed = failed or max_link_error >= .00005 or max_tip_step >= .12 or not crossings.is_empty()
		reports[treatment] = {"scene_sha256": FileAccess.get_sha256(path), "core_triangles": core.size(), "clips": clips}
		print("SUCCUBUS WINGS ", treatment, ": ", clips)
		model.free()
	var receipt := FileAccess.open(Batch.Destination + "wing-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"sample_rate": Rate, "passed": not failed, "treatments": reports}, "\t"))
	receipt.close()
	quit(1 if failed else 0)


func core_triangles(surface: RefCounted, wings: Array[PackedInt32Array]) -> PackedInt32Array:
	var body_weights := PackedFloat32Array()
	for vertex in surface.positions.size():
		var wing_weight := 0.0
		for offset in surface.stride:
			var slot: int = vertex * surface.stride + offset
			var bone: int = surface.bones[surface.joints[slot]]
			if bone in wings[0] or bone in wings[1]:
				wing_weight += surface.weights[slot]
		body_weights.append(1.0 - wing_weight)
	var result := PackedInt32Array()
	for triangle in surface.bounds.size():
		var corner: int = triangle * 3
		if body_weights[surface.indices[corner]] >= .75 and body_weights[surface.indices[corner + 1]] >= .75 and body_weights[surface.indices[corner + 2]] >= .75:
			result.append(triangle)
	assert(not result.is_empty())
	return result


func crosses_core(surface: RefCounted, core: PackedInt32Array, from: Vector3, to: Vector3) -> bool:
	var line := AABB(from, Vector3.ZERO).expand(to).grow(.0001)
	for triangle in core:
		if not line.intersects(surface.bounds[triangle]):
			continue
		var corner := triangle * 3
		if Geometry3D.segment_intersects_triangle(from, to, surface.deformed[surface.indices[corner]],
				surface.deformed[surface.indices[corner + 1]], surface.deformed[surface.indices[corner + 2]]) != null:
			return true
	return false
