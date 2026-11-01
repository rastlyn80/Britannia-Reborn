extends SceneTree
## Keep the declared sampled wing/body transforms, including landed packing.
func _initialize() -> void:
	var paths: Array[String]=["res://local-art/eagle/eagle-source.glb.import","res://local-art/eagle/eagle-modern.glb.import"]
	if "--public" in OS.get_cmdline_user_args():paths=["res://Art/Creatures/Eagle/eagle.glb.import"]
	for path: String in paths:
		var config:=ConfigFile.new()
		if config.load(path)!=OK:push_error("Import eagle before configuring precision: "+path);quit(1);return
		config.set_value("params","animation/fps",120);config.set_value("params","meshes/force_disable_compression",true)
		config.set_value("params","_subresources",{"nodes":{"PATH:AnimationPlayer":{"optimizer/enabled":false,"compression/enabled":false}}})
		if config.save(path)!=OK:quit(1);return
	print("EAGLE IMPORT: 120Hz; per-asset optimizer/compression disabled");quit()
