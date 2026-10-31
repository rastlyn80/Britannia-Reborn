extends SceneTree
## Rasterise technical SVG guides for the separate imagegen authoring step.
func _initialize() -> void:
	for kind in ["kirin","llama"]:
		var image:=Image.new()
		var path: String="res://local-art/mounts/"+kind+"-uv-template"
		var error:=image.load_svg_from_string(FileAccess.get_file_as_string(path+".svg"))
		if error!=OK:push_error("UV template rendering failed");quit(1);return
		if image.save_png(path+".png")!=OK:quit(1);return
	quit()
