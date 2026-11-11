# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const RUNTIME_NAMES := {
	"Glide": "Walk", "Rush": "Run", "RearingStrike": "Attack", "DivingStrike": "Attack2",
	"Recoil": "Hit", "Look": "Fidget", "DeathTurn": "Death", "DeathRoll": "Death2",
}


func _initialize() -> void:
	bake.call_deferred()


func bake() -> void:
	var folder := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--study="):
			folder = argument.trim_prefix("--study=")
	if folder.is_empty() or not folder.is_absolute_path():
		printerr("Pass --study= with the absolute directory from prepare-seahorse.py")
		quit(2)
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(folder.path_join("sea-horse.gltf"), state) != OK:
		quit(1)
		return
	var model := document.generate_scene(state)
	var animator := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := animator.get_animation_library("")
	for clip: String in RUNTIME_NAMES:
		if not library.has_animation(clip):
			printerr("Missing source clip ", clip)
			model.free()
			quit(1)
			return
		library.rename_animation(clip, RUNTIME_NAMES[clip])
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	if rig.get_bone_count() != 13 or library.get_animation_list().size() != 17:
		printerr("Incomplete SeaHorse import")
		model.free()
		quit(1)
		return
	animator.deterministic = true
	var scene := PackedScene.new()
	var error := scene.pack(model)
	model.free()
	if error == OK:
		error = ResourceSaver.save(scene, folder.path_join("sea-horse.scn"), ResourceSaver.FLAG_BUNDLE_RESOURCES)
	if error != OK:
		printerr("SeaHorse scene could not be saved: ", error)
		quit(1)
		return
	var digest := FileAccess.get_sha256(folder.path_join("sea-horse.scn"))
	var manifest := FileAccess.open(folder.path_join("sea-horse.json"), FileAccess.WRITE)
	if digest.length() != 64 or manifest == null:
		quit(1)
		return
	manifest.store_line(JSON.stringify({"schema": 1, "scene_sha256": digest}, "  ", true))
	print("SEAHORSE BAKE: 13 joints, 17 clips, bundled scene")
	quit()
