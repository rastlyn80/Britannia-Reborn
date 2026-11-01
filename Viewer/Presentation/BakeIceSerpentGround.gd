extends SceneTree
## Evaluate actual imported skins offline; runtime uses cheap scalar lookups.
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const KIND="serpents_snake_giant_ice"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var treatments: Dictionary={}
	for treatment in ["original","rounded","modern"]:
		var path: String="res://local-art/creatures/"+KIND+"-"+treatment+".gltf"
		var actor:=load(path).instantiate() as Node3D;root.add_child(actor)
		var player: AnimationPlayer=actor.find_children("*","AnimationPlayer",true,false)[0];var rig: Skeleton3D=actor.find_children("*","Skeleton3D",true,false)[0];var mesh: MeshInstance3D=actor.find_children("*","MeshInstance3D",true,false)[0];var clips: Dictionary={}
		for clip: String in player.get_animation_list():
			if clip=="RESET":continue
			var length:=player.get_animation(clip).length;var count:=ceili(length*960.);var samples: Array=[];player.play(clip,0.)
			for i in count+1:
				var time:=length*float(i)/count;player.seek(time,true);player.pause();rig.force_update_all_bone_transforms()
				var box:=Geometry.deformed_bounds(mesh,rig);assert(box.position.is_finite() and box.size.is_finite());samples.append([time,-box.position.y])
			clips[clip]=samples;print("ICE GROUND BAKE: ",treatment,"/",clip," ",samples.size())
		treatments[treatment]={"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import"),"clips":clips};actor.free()
	var report:={"sample_rate":960,"treatments":treatments,"recipe_sha256":FileAccess.get_sha256("res://Presentation/BakeIceSerpentGround.gd"),"geometry_sha256":FileAccess.get_sha256("res://Presentation/SkinGeometry.gd"),"scope":"Private source-derived full-skin vertical corrections; shared visual-model translation only. Actual off-grid/avatar/terrain/native acceptance remains separate."}
	FileAccess.open("res://local-art/creatures/"+KIND+"-ground.json",FileAccess.WRITE).store_string(JSON.stringify(report));print("ICE GROUND BAKE COMPLETE: three treatments; no route installed");quit()
