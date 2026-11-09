extends "res://../scripts/bake-troll-weapons-trial.gd"

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const SOURCE := "res://../work/creatures/orc_captain_actions/axe-"

func run() -> void:
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(SOURCE + "corners.json"))
	assert(rows.size() == 246)
	var atlas := Image.load_from_file(SOURCE + "atlas.png")
	assert(atlas != null and not atlas.is_empty())
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(atlas)
	material.roughness = 0.83
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	builder.set_material(material)
	for row: Array in rows:
		vertex(builder, Vector3(row[0], row[1], row[2]) * 0.86, Vector3(row[3], row[4], row[5]), Vector2(row[6], row[7]))
	var axe := builder.commit()
	for treatment: String in ["original", "rounded", "modern"]:
		var base := Registry.entry(7)
		var retained: Dictionary = base.get("classic_gesture_base_assets", {})
		var source: String = retained.get(treatment, Registry.asset_path(base, treatment))
		var digests: Dictionary = base.get("authored_action_base_sha256", base.asset_sha256)
		assert(FileAccess.get_sha256(source) == digests[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var grip := rig.find_bone("cp_grasp_rhand")
		assert(grip >= 0 and rig.get_bone_count() == 37)
		player.play("Idle", 0.0)
		player.advance(0.0)
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		var socket := rig.global_transform * rig.get_bone_global_pose(grip)
		var axis := (socket.basis.inverse() * Vector3(0.0, 0.38, 0.93)).normalized()
		var joint := rig.add_bone("orc captain axe")
		rig.set_bone_parent(joint, grip)
		rig.set_bone_rest(joint, Transform3D(Basis(Quaternion(Vector3.UP, axis)), Vector3.ZERO))
		rig.reset_bone_pose(joint)
		var prop := MeshInstance3D.new()
		prop.name = "OrcCaptainAxe"
		prop.mesh = axe
		prop.set_meta("source_visual_prop", true)
		prop.skin = Skin.new()
		prop.skin.add_bind(joint, Transform3D.IDENTITY)
		prop.skeleton = NodePath("..")
		rig.add_child(prop)
		prop.owner = model
		Exact.check_earlier_keys(player, source)
		player.stop()
		var scene := PackedScene.new()
		var target := "res://local-art/creatures/orc-captain-7-axe-%s.scn" % treatment
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, target, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print(treatment, " Orc Captain, 37 original joints and 82-triangle axe at the source grasp")
	quit()
