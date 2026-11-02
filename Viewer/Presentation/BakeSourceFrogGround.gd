extends SceneTree
## Measure the imported Hit's residual floor error before a constant bias.
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
func _initialize() -> void:
	create_timer(240.).timeout.connect(func():push_error("Frog Hit calibration deadline");quit(1));call_deferred("run")
func run() -> void:
	var preparation:="res://local-art/creatures/frogs/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation));var records: Array=[]
	for record: Dictionary in prep.models:
		for treatment in ["original","rounded","modern"]:
			var path: String="res://local-art/creatures/"+str(record.kind)+"-"+treatment+".gltf";var model: Node3D=load(path).instantiate();root.add_child(model);var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0];var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0];var mesh: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0];var skin:=Ground.skin_points(mesh,rig);player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;player.get_animation("Hit").loop_mode=Animation.LOOP_NONE;player.play("Hit",0.)
			var count:=ceili(player.current_animation_length*960.);var lowest:=INF;var highest:=-INF;var values: Array=[]
			for step in count+1:
				var time:=player.current_animation_length*float(step)/float(count);player.seek(time,true);player.advance(0.);rig.force_update_all_bone_transforms();var gap:=Ground.minimum_plane_gap(skin,rig,rig.global_transform,Vector3.ZERO,Vector3.UP);assert(is_finite(gap));lowest=minf(lowest,gap);highest=maxf(highest,gap);values.append([time,gap])
			records.append({"kind":record.kind,"treatment":treatment,"clip":"Hit","samples":values,"minimum_m":lowest,"maximum_m":highest,"constant_bias_m":-(lowest+highest)*.5,"minimax_residual_m":(highest-lowest)*.5,"source_to_world_up_scale":model.scale.z,"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import")});model.free()
	var report:={"sample_rate":960,"records":records,"recipe_sha256":FileAccess.get_sha256("res://Presentation/BakeSourceFrogGround.gd"),"geometry_sha256":FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd"),"preparation_sha256":FileAccess.get_sha256(preparation),"scope":"Actual imported complete unique-skin minima for Hit only, no contact solver. A single minimax vertical bias may centre residual sampled floor error; no per-frame flattening or recovered original-client placement claim."};FileAccess.open("res://../work/creatures/frogs/hit-calibration.json",FileAccess.WRITE).store_string(JSON.stringify(report));print("FROG HIT FLOOR MEASURED: ",records.size()," imported skins/960Hz; single clip biases, no changes applied");quit()
