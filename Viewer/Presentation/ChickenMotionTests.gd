extends SceneTree
## Inspect actual imported skins, retained source motion and authored categories.
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<16:push_error(label)
func option(name: String,fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"+name+"="):return arg.get_slice("=",1)
	return fallback
func actor(path: String) -> Dictionary:
	var model:=load(path).instantiate() as Node3D;root.add_child(model)
	return {"model":model,"rig":model.find_children("*","Skeleton3D",true,false)[0],"player":model.find_children("*","AnimationPlayer",true,false)[0],"meshes":model.find_children("*","MeshInstance3D",true,false)}
func pose(record: Dictionary,clip: String,phase: float) -> void:
	var player: AnimationPlayer=record.player;player.play(clip,0.);player.seek(player.get_animation(clip).length*phase,true);player.pause();(record.rig as Skeleton3D).force_update_all_bone_transforms()
func points(record: Dictionary) -> PackedVector3Array:
	var result:=PackedVector3Array();var rig: Skeleton3D=record.rig
	for mesh: MeshInstance3D in record.meshes:
		var matrices: Array[Transform3D]=[]
		for i in mesh.skin.get_bind_count():
			var bone:=mesh.skin.get_bind_bone(i)
			if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(i))
			matrices.append(rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(i))
		for surface in mesh.mesh.get_surface_count():
			var a:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var bones: PackedInt32Array=a[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var stride:=bones.size()/vertices.size()
			for i in vertices.size():
				var p:=Vector3.ZERO
				for j in stride:p+=(matrices[bones[i*stride+j]]*vertices[i])*weights[i*stride+j]
				result.append(rig.to_global(p))
	return result
func joint(record: Dictionary,name: String) -> Vector3:
	var rig: Skeleton3D=record.rig;return rig.to_global(rig.get_bone_global_pose(rig.find_bone(name)).origin)
func foot(record: Dictionary,side: String) -> Vector3:
	var result:=Vector3.ZERO
	for name in ["Finger1_"+side+".001","Finger2_"+side+".002","Finger3_"+side+".002","Finger4_"+side+".002"]:result+=joint(record,name)*.25
	return result
func run() -> void:
	var source_path:=option("source","res://local-art/chicken/chicken-source.glb");var modern_path:=option("modern","res://local-art/chicken/chicken-modern.glb");var metadata_path:=option("metadata","res://local-art/chicken/chicken-modern.actions.json");var output:=option("output","res://../outputs/creatures/chicken-trial/motion.json");var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(metadata_path));var source:=actor(source_path);var modern:=actor(modern_path);var player: AnimationPlayer=modern.player;var samples: Array=[];var maximum_source_error:=0.;var airborne:=0
	check((modern.rig as Skeleton3D).get_bone_count()==47 and modern.meshes.size()==2,"Original40 joints plus seven explicit curved-bone joints and both source meshes")
	check(player.get_animation_list().size()==19,"Eleven retained source clips and eight declared active categories")
	for label: String in (source.player as AnimationPlayer).get_animation_list():
		check(player.has_animation("Source"+label),"Retained source category "+label)
		for step in 17:
			var phase:=float(step)/16.;pose(source,label,phase);pose(modern,"Source"+label,phase);var a:=points(source);var b:=points(modern);var delta:=joint(modern,"Main")-joint(source,"Main");check(a.size()==b.size(),"Both complete skins retain identical vertex order")
			var error:=0.
			for i in mini(a.size(),b.size()):error=maxf(error,a[i].distance_to(b[i]-delta))
			maximum_source_error=maxf(maximum_source_error,error);check(error<.00005,"Every retained imported skin matches its source modulo declared root floor: %s %.4f"%[label,phase])
	for label in player.get_animation_list():
		var first:=PackedVector3Array();var last:=PackedVector3Array()
		for step in 33:
			var phase:=float(step)/32.;pose(modern,label,phase);var skin:=points(modern);var box:=AABB(skin[0],Vector3.ZERO);var finite:=true
			for p in skin:finite=finite and p.is_finite();box=box.expand(p)
			check(finite and box.size.length()>.1 and box.size.length()<1.2,"Every actual full hen skin remains finite and bounded")
			check(box.position.y>-.008 and box.position.y<.07,"Measured source floor and authored positive lift stay within declared range")
			if label=="Run" and box.position.y>.01:airborne+=1
			if step==0:first=skin
			if step==32:last=skin
			samples.append({"clip":label,"phase":phase,"minimum_y":box.position.y,"height":box.size.y})
		if label in ["Idle","Walk","Run","Eat","Fidget"]:
			var error:=0.
			for i in first.size():error=maxf(error,first[i].distance_to(last[i]))
			check(error<.0001,"Active cycle closes without a root or skin jump: "+label)
	check(airborne>=8,"Authored Run retains real positive airborne skin clearance")
	pose(modern,"Idle",.3);var neutral:=points(modern)
	for before in ["Run","Hit","Attack","Death","SourceDying"]:
		pose(modern,before,.65);pose(modern,"Idle",.3);var reset:=points(modern);var error:=0.
		for i in neutral.size():error=maxf(error,neutral[i].distance_to(reset[i]))
		check(error<.0001,"Shared motion and constant floor reset after "+before)
	var gait_rows: Array=[]
	for label in ["Walk","Run"]:
		var path: Array=[];var duration:=player.get_animation(label).length
		for i in 385:
			pose(modern,label,float(i)/384.);path.append({"L":foot(modern,"L"),"R":foot(modern,"R")})
		var reference:=float(metadata.locomotion.walk_reference_mps if label=="Walk" else metadata.locomotion.run_reference_mps);var native_speed:=1.8 if label=="Walk" else 6.8;var rate:=native_speed/reference;check(rate<4.,"Actual native speed selects an unclamped declared gait rate")
		if label=="Run":
			for centre in [0.,.5]:
				var middle: int=int(centre*384);var side: String="L" if path[middle].L.y<path[middle].R.y else "R"
				for index in range(1,384):
					var phase:=float(index)/384.;var distance:=absf(fposmod(phase-centre+.5,1.)-.5)
					if distance>.02:continue
					var speed: float=(path[index-1][side].z-path[index][side].z)/(duration/384.)*rate;check(absf(speed-native_speed)<.25,"Measured running stance follows native travel without inventing limb stretch");gait_rows.append({"clip":label,"phase":phase,"speed_mps":speed,"native_speed_mps":native_speed})
		else:
			for side in ["L","R"]:
				var low:=INF
				for row: Dictionary in path:low=minf(low,row[side].y)
				var speeds: Array[float]=[]
				for i in range(1,path.size()):
					var speed: float=(path[i-1][side].z-path[i][side].z)/(duration/384.)*rate
					if maxf(path[i-1][side].y,path[i][side].y)<low+.012 and speed>.001:speeds.append(speed)
				speeds.sort();check(speeds.size()>20 and absf(speeds[speeds.size()/2]-native_speed)<.15,"Measured walking median stance follows native travel");gait_rows.append({"clip":label,"side":side,"median_speed_mps":speeds[speeds.size()/2],"native_speed_mps":native_speed,"samples":speeds.size()})
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()));FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"source_samples":187,"complete_skins":samples.size(),"samples":samples,"gaits":gait_rows,"airborne_run_cases":airborne,"max_source_relative_skin_error_m":maximum_source_error,"source_asset_sha256":FileAccess.get_sha256(source_path),"asset_sha256":FileAccess.get_sha256(modern_path),"source_import_sha256":FileAccess.get_sha256(source_path+".import"),"import_sha256":FileAccess.get_sha256(modern_path+".import"),"metadata_sha256":FileAccess.get_sha256(metadata_path),"test_sha256":FileAccess.get_sha256(get_script().resource_path),"scope":"Actual saved/imported full skins, original relative motion, authored categories, loops, cross-action root/floor resets and finite gait landmark rates. Not native server, final art or arbitrary terrain certification."},"  "));source.model.free();modern.model.free();print("CHICKEN MOTION: ",checks," / ",failures," failures; ",samples.size()," complete skins /187 retained-source comparisons");quit(1 if failures else 0)
