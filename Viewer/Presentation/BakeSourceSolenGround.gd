extends SceneTree
## Measure imported Attack2 residual only; source gait/root channels stay intact.
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
func _initialize() -> void:
	create_timer(300.).timeout.connect(func():push_error("Solen source calibration deadline");quit(1));call_deferred("run")
func run() -> void:
	var preparation:="res://local-art/creatures/solen_workers/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation));var records: Array=[]
	for record: Dictionary in prep.models:
		for treatment in ["original","rounded","modern"]:
			var path: String="res://local-art/creatures/"+str(record.kind)+"-"+treatment+".gltf";var model: Node3D=load(path).instantiate();root.add_child(model);var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0];var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0];var mesh: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0];var skin:=Ground.skin_points(mesh,rig);player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;player.get_animation("Attack2").loop_mode=Animation.LOOP_NONE;player.play("Attack2",0.)
			var count:=ceili(player.current_animation_length*960.);var low:=INF;var high:=-INF;var values: Array=[]
			for step in count+1:
				var time:=player.current_animation_length*float(step)/float(count);player.seek(time,true);player.advance(0.);rig.force_update_all_bone_transforms();var gap:=Ground.minimum_plane_gap(skin,rig,rig.global_transform,Vector3.ZERO,Vector3.UP);assert(is_finite(gap));low=minf(low,gap);high=maxf(high,gap);values.append([time,gap])
			records.append({"kind":record.kind,"treatment":treatment,"clip":"Attack2","samples":values,"minimum_m":low,"maximum_m":high,"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import")});model.free()
	var report:={"sample_rate":960,"records":records,"recipe_sha256":FileAccess.get_sha256("res://Presentation/BakeSourceSolenGround.gd"),"geometry_sha256":FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd"),"preparation_sha256":FileAccess.get_sha256(preparation),"scope":"Actual imported complete unique-skin minima for Attack2 only. Small residual correction after source floor placement; original Walk/Run and source joint channels untouched. Not native original-client placement or arbitrary-time certification."};FileAccess.open("res://../work/creatures/solen/attack-calibration.json",FileAccess.WRITE).store_string(JSON.stringify(report));print("SOLEN ATTACK FLOOR MEASURED:6imported skins/960Hz");quit()
