extends SceneTree
const Geometry=preload("res://Presentation/SourceGroundLookup.gd")
const FOLDER="res://local-art/creatures/"
const KIND="serpents_snake_giant_silver"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var treatments: Dictionary={}
	for treatment in ["original","rounded","modern"]:
		var path: String=FOLDER+KIND+"-"+str(treatment)+".gltf";var actor:=load(path).instantiate() as Node3D;root.add_child(actor)
		var player: AnimationPlayer=actor.find_children("*","AnimationPlayer",true,false)[0];var rig: Skeleton3D=actor.find_children("*","Skeleton3D",true,false)[0];var mesh: MeshInstance3D=actor.find_children("*","MeshInstance3D",true,false)[0];var clips: Dictionary={};var skin:=Geometry.skin_points(mesh,rig);player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip: String in player.get_animation_list():
			if clip=="RESET":continue
			var length:=player.get_animation(clip).length;var count:=ceili(length*960.);var samples: Array=[];player.get_animation(clip).loop_mode=Animation.LOOP_NONE;player.play(clip,0.)
			for i in count+1:
				var time:=length*float(i)/count;player.seek(time,true);player.advance(0.);player.pause();rig.force_update_all_bone_transforms()
				var gap:=Geometry.minimum_plane_gap(skin,rig,rig.global_transform,Vector3.ZERO,Vector3.UP);assert(is_finite(gap));samples.append([time,-gap])
			clips[clip]=samples;print("SILVER GROUND BAKE: ",treatment,"/",clip," ",samples.size())
		treatments[treatment]={"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import"),"clips":clips};actor.free()
	var report:={"sample_rate":960,"treatments":treatments,"recipe_sha256":FileAccess.get_sha256("res://Presentation/BakeSourceSilverSerpentGround.gd"),"geometry_sha256":FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd"),"scope":"Exact original Silver saved-import full-skin floor correction measurements; scalar visual-only correction, no accepted terrain/native routes."}
	FileAccess.open(FOLDER+KIND+"-ground.json",FileAccess.WRITE).store_string(JSON.stringify(report));print("SILVER GROUND BAKE COMPLETE");quit()
