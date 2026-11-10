# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/check-grizzle-changeling-clearance.gd"

const Pair := preload("bake-raptor-slith-enhanced.gd")
const RaptorTorso := ["Body", "Hips", "Torso", "Shoulders", "Neck", "Back"]
const SlithTorso := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 neck", "bip01 neck1"]
const RaptorFeet := ["BackFoot.L", "BackFoot.R", "BackFoot.L_end", "BackFoot.R_end", "BackLowLeg.L_end", "BackLowLeg.R_end"]
const SlithFeet := ["bip01 l hand", "bip01 r hand", "bip01 l foot", "bip01 r foot"]


func run() -> void:
	var report := {}
	for body: int in [730, 734]:
		var treatments := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var path := Pair.Destination + "%d-%s.scn" % [body, treatment]
			var model := (load(path) as PackedScene).instantiate()
			root.add_child(model)
			var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var mesh := model.find_child("Velociraptor" if body == 730 else "Body", true, false) as MeshInstance3D
			var surfaces := measurement_surfaces(mesh, rig, body)
			var clips: Array = Pair.Raptor.values() if body == 730 else Pair.Slith.values() + [Pair.Breath]
			var metrics := {}
			for clip: String in clips:
				metrics[clip] = measure_clip(player, rig, surfaces, body, clip)
				print("REPTILE GEOMETRY ", body, "/", treatment, "/", clip, " ", metrics[clip])
			for row: Dictionary in surfaces:
				row.surface.mesh.free()
			treatments[treatment] = {"scene_sha256": FileAccess.get_sha256(path), "clips": metrics}
			model.free()
		report[str(body)] = treatments
	var receipt := FileAccess.open(Pair.Destination + "dense-clearance-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"sample_rate": Rate, "bodies": report}, "\t"))
	receipt.close()
	quit()


func measurement_surfaces(mesh: MeshInstance3D, rig: Skeleton3D, body: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var torso := RaptorTorso if body == 730 else SlithTorso
	var feet := RaptorFeet if body == 730 else SlithFeet
	var core := 0
	var foot_count := 0
	for slot in mesh.mesh.get_surface_count():
		var copy := ArrayMesh.new()
		copy.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.mesh.surface_get_arrays(slot))
		var probe := MeshInstance3D.new()
		probe.mesh = copy
		probe.skin = mesh.skin
		var surface := PosedSurface.new(probe, rig)
		var triangles := core_triangles(surface, rig, torso)
		var support := PackedInt32Array()
		for vertex in surface.positions.size():
			var influence := vertex * surface.stride
			if rig.get_bone_name(surface.bones[surface.joints[influence]]) in feet and surface.weights[influence] > .7:
				support.append(vertex)
		core += triangles.size()
		foot_count += support.size()
		result.append({"surface": surface, "torso": triangles, "feet": support})
	assert(core > 0 and foot_count > 0)
	return result


func measure_clip(player: AnimationPlayer, rig: Skeleton3D, surfaces: Array[Dictionary], body: int, clip: String) -> Dictionary:
	var labels := [["FrontLowLeg.L", "FrontFoot.L"], ["FrontLowLeg.R", "FrontFoot.R"],
		["Tail3", "Tail4"], ["Tail4", "Tail5"], ["Tail5", "Tail5_end"]] if body == 730 else [
		["bip01 l forearm", "bip01 l hand"], ["bip01 r forearm", "bip01 r hand"], ["bip01 tail1", "bip01 tail2"]]
	var segments := []
	for pair: Array in labels:
		segments.append([rig.find_bone(pair[0]), rig.find_bone(pair[1])])
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var intervals := ceili(player.current_animation_length * Rate)
	var crossings := 0
	var floor_minimum := INF
	var foot_clearance := 0.0
	for sample in intervals + 1:
		player.seek(player.current_animation_length * sample / intervals, true)
		rig.force_update_all_bone_transforms()
		var hit := false
		var support := INF
		var lowest := INF
		for row: Dictionary in surfaces:
			var surface: RefCounted = row.surface
			surface.update_pose()
			for segment: Array in segments:
				hit = crosses(surface, row.torso, joint_position(rig, segment[0]), joint_position(rig, segment[1])) or hit
			for point: Vector3 in surface.deformed:
				lowest = minf(lowest, point.y)
			for index: int in row.feet:
				support = minf(support, surface.deformed[index].y)
		assert(is_finite(support))
		floor_minimum = minf(floor_minimum, lowest)
		# Runtime places the lowest skin point 3 mm above the plane.
		foot_clearance = maxf(foot_clearance, support - lowest + .003)
		crossings += 1 if hit else 0
	return {"samples": intervals + 1, "crossings": crossings, "floor_minimum": floor_minimum,
		"maximum_supported_foot_gap": foot_clearance}
