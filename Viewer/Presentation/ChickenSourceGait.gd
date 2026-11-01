extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/creatures/chicken-trial"))
	var actor:=load("res://local-art/chicken/chicken-source.glb").instantiate() as Node3D;root.add_child(actor);var rig:=actor.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D;var player:=actor.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer;var samples: Array=[];var duration:=player.get_animation("Walk").length
	for i in 129:
		player.play("Walk",0.);player.seek(duration*float(i)/128.,true);player.pause();rig.force_update_all_bone_transforms();var feet: Dictionary={}
		for side in ["L","R"]:
			var tips: Array=[]
			for name in ["Finger1_"+side+".001","Finger2_"+side+".002","Finger3_"+side+".002","Finger4_"+side+".002"]:
				var bone:=rig.find_bone(name);var point:=rig.to_global(rig.get_bone_global_pose(bone).origin);tips.append([point.x,point.y,point.z])
			feet[side]=tips
		samples.append({"phase":float(i)/128.,"feet":feet})
	FileAccess.open("res://../outputs/creatures/chicken-trial/source-gait.json",FileAccess.WRITE).store_string(JSON.stringify({"duration":duration,"samples":samples,"asset_sha256":FileAccess.get_sha256("res://local-art/chicken/chicken-source.glb"),"import_sha256":FileAccess.get_sha256("res://local-art/chicken/chicken-source.glb.import"),"test_sha256":FileAccess.get_sha256(get_script().resource_path),"scope":"Private retained foot/toe landmark cadence probe; not native acceptance or arbitrary-terrain proof."}));print("CHICKEN GAIT LANDMARKS: ",samples.size()," / ",duration," seconds");actor.free();quit()
