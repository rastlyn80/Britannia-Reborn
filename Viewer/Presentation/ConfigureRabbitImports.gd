extends SceneTree
## Preserve small, fast source paws and the declared common-root gait curves.
func _initialize() -> void:
	var paths: Array[String]=["res://local-art/rabbit/rabbit-source.glb","res://local-art/rabbit/rabbit-modern.glb"]
	if "--public" in OS.get_cmdline_user_args():paths=["res://Art/Creatures/Rabbit/rabbit.glb"]
	for path in paths:
		var file:=ConfigFile.new()
		if file.load(path+".import")!=OK:push_error("Import the rabbit model before configuring precision");quit(1);return
		file.set_value("params","animation/fps",240);file.set_value("params","meshes/force_disable_compression",true)
		var subresources: Dictionary=file.get_value("params","_subresources",{});var nodes: Dictionary=subresources.get("nodes",{});var player: Dictionary=nodes.get("PATH:AnimationPlayer",{})
		player["optimizer/enabled"]=false;player["compression/enabled"]=false;nodes["PATH:AnimationPlayer"]=player;subresources["nodes"]=nodes;file.set_value("params","_subresources",subresources)
		if file.save(path+".import")!=OK:push_error("Rabbit import precision must persist");quit(1);return
	print("RABBIT IMPORTS: 240Hz, uncompressed skin and source/declared animation keys preserved");quit()
