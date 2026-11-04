extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")

func _initialize() -> void:
	create_timer(15.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	for body in [35, 36]:
		var form := "Spear" if body == 35 else "Mace"
		var record := Registry.entry(body).duplicate(true)
		assert(not record.is_empty())
		record.assets = {"modern": "res://local-art/creatures/lizardman-pillage-trial-%s.scn" % form.to_lower()}
		Registry.entries[body] = record
		for hue in [0, 53, 0x8035]:
			var posed := Corpses.posed(body, hue)
			assert(posed != null)
			var weapon := posed.find_child(form, true, false) as MeshInstance3D
			var rig := weapon.get_parent() as Skeleton3D
			var bone := rig.find_bone("lizardman weapon")
			assert(bone >= 0 and weapon.skin.get_bind_bone(0) == bone)
			var expected := posed.global_transform.affine_inverse() * rig.global_transform * rig.get_bone_global_pose(bone)
			var corpse := Corpses.freeze(posed)
			assert(corpse != null and corpse.get_meta("graphic_id") == 0x2006)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			var frozen := corpse.get_node(form) as MeshInstance3D
			assert(frozen != null)
			var points: PackedVector3Array = frozen.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			assert(points.size() == (84 if body == 35 else 270))
			var source: PackedVector3Array = weapon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var lift := (frozen.transform * points[0]).y - (expected * source[0]).y
			var error := 0.0
			for i in points.size():
				var expected_point := expected * source[i] + Vector3.UP * lift
				error = maxf(error, expected_point.distance_to(frozen.transform * points[i]))
			assert(error < 0.0001)
			assert(frozen.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES] == null)
			print(body, " hue ", hue, " ", points.size(), " weapon vertices match the last skeletal pose; max error ", error)
			corpse.free()
			posed.queue_free()
	await process_frame
	quit()
