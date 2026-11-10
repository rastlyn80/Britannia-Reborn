# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Batch := preload("bake-orc-captain-solen-enhanced.gd")
const PosedSurface := preload("res://../scripts/ophidian-bardiche-clearance.gd")
const Rate := 240


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var reports := {}
	for body: int in [7, 805]:
		var rows := {}
		var clips := Batch.Captain if body == 7 else Batch.Worker
		for treatment: String in ["original", "rounded", "modern"]:
			var path := Batch.Destination + "%d-%s.scn" % [body, treatment]
			var model := (load(path) as PackedScene).instantiate()
			root.add_child(model)
			var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var surface := PosedSurface.new(model.find_child("Body", true, false), rig)
			var feet := foot_points(surface, rig, body)
			var receipts := {}
			for clip: String in clips.values():
				var row := measure(body, player, rig, surface, feet, clip)
				receipts[clip] = row
				print("CAPTAIN AND SOLEN GEOMETRY ", body, "/", treatment, "/", clip, ": ", row)
			rows[treatment] = {"scene_sha256": FileAccess.get_sha256(path), "clips": receipts}
			model.free()
		reports[str(body)] = rows
	var receipt := FileAccess.open(Batch.Destination + "dense-geometry-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"sample_rate": Rate, "bodies": reports}, "\t"))
	receipt.close()
	quit()


func foot_points(surface: RefCounted, rig: Skeleton3D, body: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for vertex in surface.positions.size():
		var weight := 0.0
		for index in surface.stride:
			var slot: int = vertex * surface.stride + index
			var label := rig.get_bone_name(surface.bones[surface.joints[slot]])
			if (body == 805 and label.begins_with("legbone") and label.ends_with("2")) or (
					body == 7 and (" toe" in label or label.ends_with(" foot"))):
				weight += surface.weights[slot]
		if weight > .70:
			result.append(vertex)
	assert(not result.is_empty())
	return result


func measure(body: int, player: AnimationPlayer, rig: Skeleton3D, surface: RefCounted, feet: PackedInt32Array,
		clip: String) -> Dictionary:
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var intervals := ceili(player.current_animation_length * Rate)
	var lifted := 0.0
	var lowest := INF
	var crossed := PackedFloat32Array()
	var axe := rig.find_bone(Batch.AxeBone)
	for sample in intervals + 1:
		var phase := float(sample) / intervals
		player.seek(player.current_animation_length * phase, true)
		rig.force_update_all_bone_transforms()
		surface.update_pose()
		var foot := INF
		for vertex in feet:
			foot = minf(foot, (surface.deformed[vertex] as Vector3).y)
		lifted = maxf(lifted, foot)
		lowest = minf(lowest, foot)
		if body == 7:
			var frame := rig.global_transform * rig.get_bone_global_pose(axe)
			if crosses_captain_axe(surface, frame):
				crossed.append(phase)
	return {"samples": intervals + 1, "minimum_foot_height": lowest, "maximum_foot_height": lifted,
		"axe_crossings": crossed.size(), "first_crossing_phase": -1.0 if crossed.is_empty() else crossed[0],
		"last_crossing_phase": -1.0 if crossed.is_empty() else crossed[-1]}


func crosses_captain_axe(surface: RefCounted, frame: Transform3D) -> bool:
	# Centreline witnesses along both ends of the shaft and three blade chords.
	var segments := [
		[Vector3(0, -.214, 0), Vector3(0, -.10, 0)],
		[Vector3(0, .10, 0), Vector3(0, .838, 0)],
		[Vector3(0, .56, 0), Vector3(0, .73, .134)],
		[Vector3(0, .56, 0), Vector3(0, .73, -.134)],
		[Vector3(0, .71, -.132), Vector3(0, .71, .132)],
	]
	for segment: Array in segments:
		var start: Vector3 = frame * segment[0]
		var finish: Vector3 = frame * segment[1]
		var limits := AABB(start, Vector3.ZERO).expand(finish).grow(.018)
		for triangle in surface.bounds.size():
			if not limits.intersects(surface.bounds[triangle]):
				continue
			var corner: int = triangle * 3
			for offset: float in [-.008, 0.0, .008]:
				var shift := frame.basis.x * offset
				if Geometry3D.segment_intersects_triangle(start + shift, finish + shift,
						surface.deformed[surface.indices[corner]], surface.deformed[surface.indices[corner + 1]],
						surface.deformed[surface.indices[corner + 2]]) != null:
					return true
	return false
