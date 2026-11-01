extends SceneTree
## Preserve short-stance motion; imported paw speeds/soles are tested afterward.
func _initialize() -> void:
	var folder:="res://local-art/cat";var names: Array[String]=["cat-source.glb","cat-modern.glb"]
	if "--public" in OS.get_cmdline_user_args():folder="res://Art/Creatures/Cat";names=["cat.glb"]
	for name in names:
		var path:=folder+"/"+name+".import";var config:=ConfigFile.new()
		if config.load(path)!=OK:push_error("Import cat before configuring precision: "+path);quit(1);return
		config.set_value("params","animation/fps",240);config.set_value("params","meshes/force_disable_compression",true)
		config.set_value("params","_subresources",{"nodes":{"PATH:AnimationPlayer":{"optimizer/enabled":false,"compression/enabled":false}}})
		if config.save(path)!=OK:quit(1);return
	print("CAT IMPORT: 240Hz; measured AnimationPlayer optimizer/compression disabled");quit()
