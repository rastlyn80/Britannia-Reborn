# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-troll-weapons-trial.gd"

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const SOURCE := "res://../work/creatures/orc_captain_actions/axe-"

func run() -> void:
	var destination := "res://local-art/creatures/orc-lord-prepared"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			destination = argument.trim_prefix("--output=")
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination)) == OK)
	var inputs := {
		"mesh": "b342bc101a36327e8a2d799c5eb076f0372893ac9cd41f3acf5b679c457683c9",
		"atlas": "6b6db69ff83ce1950113b4c10965a42e730eb4887fab16e11ccfb064f661f720",
	}
	var manifest := {"schema": 1, "body": 138, "axe_source_sha256": inputs, "base": {}, "assets": {}}
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
		var base := Registry.entry(138)
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
		var joint := rig.add_bone("orc lord axe")
		rig.set_bone_parent(joint, grip)
		rig.set_bone_rest(joint, Transform3D(Basis(Quaternion(Vector3.UP, axis)), Vector3.ZERO))
		rig.reset_bone_pose(joint)
		var prop := MeshInstance3D.new()
		prop.name = "OrcLordAxe"
		prop.mesh = axe
		prop.set_meta("source_visual_prop", true)
		prop.skin = Skin.new()
		prop.skin.add_bind(joint, Transform3D.IDENTITY)
		prop.skeleton = NodePath("..")
		rig.add_child(prop)
		prop.owner = model
		Exact.check_earlier_keys(player, source)
		player.stop()
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
		var scene := PackedScene.new()
		var target := destination.path_join("orc-lord-axe-%s.scn" % treatment)
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, target, ResourceSaver.FLAG_COMPRESS) == OK)
		manifest.base[treatment] = FileAccess.get_sha256(source)
		manifest.assets[treatment] = FileAccess.get_sha256(target)
		model.free()
		print(treatment, " Orcish Lord, 37 original joints and 82-triangle axe at the source grasp")
	var file := FileAccess.open(destination.path_join("manifest.json"), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()
	quit()
