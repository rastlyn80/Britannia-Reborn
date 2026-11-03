extends SceneTree
## Pack the checked private Kabur scenes for the normal resource loader.
const INPUT := "res://../work/creatures/juka/lord-owned/"
const OUTPUT := "res://local-art/creatures/juka_lord/"
var output := OUTPUT

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	for treatment in ["original", "modern"]:
		if not bake(treatment):
			push_error("Juka Lord bake failed: " + treatment)
			quit(1)
			return
	print("JUKA LORD BAKE: original and refined scenes")
	quit()

func bake(treatment: String) -> bool:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var file := "npc_kabur-" + treatment
	if document.append_from_file(ProjectSettings.globalize_path(INPUT + file + ".gltf"), state) != OK:
		return false
	var model := document.generate_scene(state)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var animator := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var scene := PackedScene.new()
	var packed := rig.get_bone_count() == 36 and animator.get_animation_list().size() == 13 and scene.pack(model) == OK
	model.free()
	return packed and ResourceSaver.save(scene, output.path_join(file + ".scn"), ResourceSaver.FLAG_COMPRESS) == OK
