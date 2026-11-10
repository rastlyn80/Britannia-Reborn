# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Batch := preload("bake-matriarch-succubus-enhanced.gd")
const StaffClearance := preload("res://Presentation/matriarch-sceptre-clearance.gd")
const Rate := 240


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var reports := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var path := Batch.Destination + "87-%s.scn" % treatment
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var body := model.find_child("Body", true, false) as MeshInstance3D
		var staff := model.find_child("MatriarchSceptre", true, false) as MeshInstance3D
		var points: PackedVector3Array = staff.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var joint := rig.find_bone(Batch.Staff)
		var clearance := StaffClearance.new(body, rig)
		var prop_bounds := staff.mesh.get_aabb()
		clearance.shaft = Vector2(prop_bounds.position.y, prop_bounds.end.y)
		var clips := {}
		for clip: String in Batch.Matriarch.values():
			player.stop()
			player.play(clip, 0.0)
			player.advance(0.0)
			var count := ceili(player.current_animation_length * Rate) + 1
			var lowest := INF
			var crossings := PackedFloat32Array()
			for sample in count:
				var phase := float(sample) / (count - 1)
				player.seek(phase * player.current_animation_length, true)
				rig.force_update_all_bone_transforms()
				clearance.update_pose()
				var staff_frame := rig.global_transform * rig.get_bone_global_pose(joint)
				if clearance.crosses_sceptre(staff_frame, .008):
					crossings.append(phase)
				for point: Vector3 in points:
					lowest = minf(lowest, (staff_frame * point).y)
			clips[clip] = {"samples": count, "crossings": crossings.size(), "floor": lowest,
				"first_crossing": -1.0 if crossings.is_empty() else crossings[0],
				"last_crossing": -1.0 if crossings.is_empty() else crossings[-1]}
		reports[treatment] = {"scene_sha256": FileAccess.get_sha256(path), "clips": clips}
		print("MATRIARCH SCEPTRE ", treatment, ": ", clips)
		model.free()
	var receipt := FileAccess.open(Batch.Destination + "sceptre-clearance.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"sample_rate": Rate, "treatments": reports}, "\t"))
	receipt.close()
	quit()
