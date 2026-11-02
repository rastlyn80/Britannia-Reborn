extends SceneTree
## Actual imported skin residuals; source animation/rig/native roots stay intact.
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
const FOLDER="res://local-art/creatures/"
const KIND="walking_dead_mummy"
func _initialize() -> void:
	create_timer(180.).timeout.connect(func():push_error("Mummy ground bake deadline");quit(1));call_deferred("run")
func run() -> void:
	var preparation_pin:=FileAccess.get_sha256(FOLDER+"mummies/preparation.json")
	var recipe_pin:=FileAccess.get_sha256("res://Presentation/BakeSourceMummyGround.gd");var geometry_pin:=FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd")
	var treatments: Dictionary={}
	for treatment: String in ["original","rounded","modern"]:
		var path:=FOLDER+KIND+"-"+treatment+".gltf";var asset_pin:=FileAccess.get_sha256(path);var import_pin:=FileAccess.get_sha256(path+".import")
		var actor:=load(path).instantiate() as Node3D;root.add_child(actor)
		var player: AnimationPlayer=actor.find_children("*","AnimationPlayer",true,false)[0];var rig: Skeleton3D=actor.find_children("*","Skeleton3D",true,false)[0];var mesh: MeshInstance3D=actor.find_children("*","MeshInstance3D",true,false)[0]
		var skin:=Ground.skin_points(mesh,rig);var clips: Dictionary={};player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip: String in player.get_animation_list():
			if clip=="RESET":continue
			var length:=player.get_animation(clip).length;var count:=ceili(length*960.);var samples: Array=[];var maximum:=0.
			player.get_animation(clip).loop_mode=Animation.LOOP_NONE;player.play(clip,0.)
			for i in count+1:
				var time:=length*float(i)/float(count);player.seek(time,true);player.advance(0.);player.pause();rig.force_update_all_bone_transforms()
				var gap:=Ground.minimum_plane_gap(skin,rig,rig.global_transform,Vector3.ZERO,Vector3.UP)
				assert(is_finite(gap));samples.append([time,-gap]);maximum=maxf(maximum,absf(gap))
			clips[clip]=samples;print("MUMMY GROUND BAKE: ",treatment,"/",clip," samples",samples.size()," maximumResidual",maximum)
		assert(asset_pin==FileAccess.get_sha256(path) and import_pin==FileAccess.get_sha256(path+".import"))
		treatments[treatment]={"asset_sha256":asset_pin,"import_sha256":import_pin,"clips":clips};actor.free()
	assert(preparation_pin==FileAccess.get_sha256(FOLDER+"mummies/preparation.json") and recipe_pin==FileAccess.get_sha256("res://Presentation/BakeSourceMummyGround.gd") and geometry_pin==FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd"))
	var report:={"sample_rate":960,"treatments":treatments,"recipe_sha256":recipe_pin,"geometry_sha256":geometry_pin,"preparation_sha256":preparation_pin,"scope":"Actual imported original/refined complete-skin residuals after original converter floor placement. Scalar model-only support; no animation/joint/native coordinate edits. Separate arbitrary-time proof required; no native terrain/render/material/corpse/acceptance claim."}
	FileAccess.open(FOLDER+KIND+"-ground.json",FileAccess.WRITE).store_string(JSON.stringify(report));print("MUMMY GROUND BAKE COMPLETE");quit()
