# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Rotting := preload("bake-rotting-corpse-enhanced.gd")
const Bog := preload("bake-bog-thing-enhanced.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const PosedSurface := preload("res://../scripts/ophidian-bardiche-clearance.gd")
const Rate := 240


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var bodies := {}
	for body: int in [155, 780]:
		var treatments := {}
		var row := Registry.entry(body)
		var clips := Rotting.Clips if body == 155 else Bog.Clips
		for treatment: String in row.assets:
			var path := Rotting.Destination + "%d-%s.scn" % [body, treatment]
			var model := (load(path) as PackedScene).instantiate()
			root.add_child(model)
			var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var surface := PosedSurface.new(mesh, rig)
			var footprint := PackedInt32Array()
			if body == 780:
				var points: Array = JSON.parse_string(FileAccess.get_file_as_string(row.footprint))
				footprint = PackedInt32Array(points)
				assert(footprint.size() == 103)
			else:
				footprint = feet(surface, rig)
			assert(not footprint.is_empty())
			var measured := {}
			for clip: String in clips.values():
				measured[clip] = measure(player, rig, surface, footprint, clip)
				print("ROTTING CORPSE AND BOG THING GEOMETRY ", body, "/", treatment, "/", clip, ": ", measured[clip])
			treatments[treatment] = {"scene_sha256": FileAccess.get_sha256(path), "clips": measured}
			model.free()
		bodies[str(body)] = treatments
	var receipt := FileAccess.open(Rotting.Destination + "dense-geometry-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"sample_rate": Rate, "bodies": bodies}, "\t"))
	receipt.close()
	quit()


func feet(surface: RefCounted, rig: Skeleton3D) -> PackedInt32Array:
	var result := PackedInt32Array()
	for vertex in surface.positions.size():
		var weight := 0.0
		for index in surface.stride:
			var slot: int = vertex * surface.stride + index
			var label := rig.get_bone_name(surface.bones[surface.joints[slot]])
			if label.ends_with(" foot") or " toe" in label:
				weight += surface.weights[slot]
		if weight > .70:
			result.append(vertex)
	return result


func measure(player: AnimationPlayer, rig: Skeleton3D, surface: RefCounted,
		footprint: PackedInt32Array, clip: String) -> Dictionary:
	player.play(clip, 0.0)
	player.advance(0.0)
	var intervals := ceili(player.current_animation_length * Rate)
	var floor_minimum := INF
	var unsupported_gap := 0.0
	var deepest := {}
	var first_height := 0.0
	var peak_height := 0.0
	var last_height := 0.0
	for sample in intervals + 1:
		player.seek(player.current_animation_length * sample / float(intervals), true)
		rig.force_update_all_bone_transforms()
		surface.update_pose()
		var floor := INF
		var lowest := -1
		var top := -INF
		for vertex in surface.deformed.size():
			var point: Vector3 = surface.deformed[vertex]
			if point.y < floor:
				floor = point.y
				lowest = vertex
			top = maxf(top, point.y)
		var support := INF
		for index in footprint:
			support = minf(support, (surface.deformed[index] as Vector3).y)
		floor_minimum = minf(floor_minimum, floor)
		if support - floor > unsupported_gap:
			unsupported_gap = support - floor
			var influences := {}
			for index in surface.stride:
				var slot: int = lowest * surface.stride + index
				if surface.weights[slot] > 0.0:
					var label := rig.get_bone_name(surface.bones[surface.joints[slot]])
					influences[label] = surface.weights[slot]
			deepest = {"phase": float(sample) / intervals, "vertex": lowest, "influences": influences}
		var height := top - floor
		peak_height = maxf(peak_height, height)
		if sample == 0:
			first_height = height
		if sample == intervals:
			last_height = height
	return {"samples": intervals + 1, "floor_minimum": floor_minimum, "unsupported_gap": unsupported_gap,
		"deepest": deepest, "first_height": first_height, "peak_height": peak_height, "last_height": last_height}
