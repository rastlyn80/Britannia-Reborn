extends SceneTree
## Complete licensed/refined skins, real limb lengths, stance speed and muzzle.
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<20:push_error(label)
func points(mesh: MeshInstance3D,rig: Skeleton3D,surface: int) -> PackedVector3Array:
	var matrices: Array[Transform3D]=[]
	for bind in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(bind)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
		matrices.append(rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
	var arrays:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var stride:=bones.size()/vertices.size();var result:=PackedVector3Array()
	for vertex in vertices.size():
		var p:=Vector3.ZERO
		for j in stride:p+=(matrices[bones[vertex*stride+j]]*vertices[vertex])*weights[vertex*stride+j]
		result.append(rig.to_global(p))
	return result
func bone_point(rig: Skeleton3D,name: String) -> Vector3:return rig.to_global(rig.get_bone_global_pose(rig.find_bone(name)).origin)
func run() -> void:
	var folder:="res://local-art/cat";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/preparation.json"));var output:="res://../outputs/creatures/cat-trial";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var viewport:=SubViewport.new();viewport.size=Vector2i(1000,750);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.85;camera.near=.001;viewport.add_child(camera);camera.position=Vector3(.8,.45,1.);camera.look_at(Vector3(0.,.18,0.))
	var samples: Array=[];var assets: Dictionary={};var envelope:=AABB();var first_envelope:=true;var run_samples: Array=[];var gallop_samples: Array=[]
	for treatment: String in ["source","modern"]:
		var path:=folder+"/cat-"+treatment+".glb";assets[treatment]={"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import")}
		check(assets[treatment].asset_sha256==prep.treatments[treatment].asset_sha256,"Exact recipe output: "+treatment)
		var model: Node3D=load(path).instantiate();viewport.add_child(model)
		var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0];var mesh: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0];var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
		check(rig.get_bone_count()==24,"All24 source bones and control roots retained with explicit aliases")
		var triangle_count:=0;var skin_valid:=true;var pink:=-1;var eyes:=0
		for surface in mesh.mesh.get_surface_count():
			var arrays:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var stride:=weights.size()/vertices.size();triangle_count+=arrays[Mesh.ARRAY_INDEX].size()/3
			skin_valid=skin_valid and stride==8
			for i in vertices.size():
				var total:=0.
				for j in stride:total+=weights[i*stride+j];skin_valid=skin_valid and weights[i*stride+j]>=0. and is_finite(weights[i*stride+j])
				skin_valid=skin_valid and absf(total-1.)<.0001
			var material:=mesh.get_active_material(surface) as StandardMaterial3D
			if material.resource_name.begins_with("CatEye"):eyes+=1
			if material.resource_name=="CatPink":pink=surface
		check(skin_valid,"All actual surfaces retain finite normalized eight-influence skin weights")
		check(triangle_count==int(prep.treatments[treatment].triangles),"Actual source/refined triangle inventory")
		check(pink>=0 and (eyes==3 if treatment=="modern" else eyes==0),"Original pink features and explicitly added eye surfaces are distinguishable")
		player.play("Idle",0.);player.seek(0.,true);player.pause();for frame in 2:await process_frame
		var original_pink:=points(mesh,rig,pink);var nose_indices: Array[int]=[];var front:=-INF
		for p in original_pink:front=maxf(front,p.z)
		for i in original_pink.size():
			if original_pink[i].z>front-.003:nose_indices.append(i)
		check(not nose_indices.is_empty(),"Muzzle selection uses actual original pink nose vertices")
		var legs: Array=[]
		for side: String in ["l","r"]:
			for names in [["thigh","calf","foot"],["upperarm","forearm","hand"]]:
				var a: String="bip01 "+side+" "+str(names[0]);var b: String="bip01 "+side+" "+str(names[1]);var c: String="bip01 "+side+" "+str(names[2])
				legs.append({"a":a,"b":b,"c":c,"first":bone_point(rig,a).distance_to(bone_point(rig,b)),"second":bone_point(rig,b).distance_to(bone_point(rig,c))})
		for clip: String in prep.clips:
			check(player.has_animation(clip),"Declared cat category exists: "+clip)
			if not player.has_animation(clip):continue
			var animation:=player.get_animation(clip);animation.loop_mode=Animation.LOOP_NONE;player.play(clip,0.);player.pause();var first: Array[Vector3]=[]
			for i in (81 if clip=="Gallop" else 21 if clip=="Run" else 13):
				var phase:=float(i)/(80. if clip=="Gallop" else 20. if clip=="Run" else 12.);player.seek(animation.length*phase,true);for frame in 2:await process_frame
				var bounds:=Geometry.deformed_bounds(mesh,rig);check(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length()>.3 and bounds.size.length()<1.,"Complete cat skin remains bounded")
				if treatment=="modern":check(bounds.position.y>-.005,"Refined actual skin remains above the floor")
				var finite:=true
				for b in rig.get_bone_count():
					var pose:=rig.get_bone_global_pose(b);finite=finite and pose.origin.is_finite() and pose.basis.is_finite() and pose.basis.determinant()>.9
					if i==0:first.append(rig.to_global(pose.origin))
				check(finite,"Every retained bone stays finite and uncollapsed")
				if phase==1. and bool(prep.clips[clip].loop):
					var maximum:=0.
					for b in rig.get_bone_count():maximum=maxf(maximum,first[b].distance_to(rig.to_global(rig.get_bone_global_pose(b).origin)))
					check(maximum<.001,"Source/authored cat loop closes: "+clip)
				if clip in ["Run","Gallop"]:
					for leg: Dictionary in legs:
						check(absf(bone_point(rig,leg.a).distance_to(bone_point(rig,leg.b))-float(leg.first))<.0005 and absf(bone_point(rig,leg.b).distance_to(bone_point(rig,leg.c))-float(leg.second))<.0005,"Authored bound preserves measured source leg lengths")
					if treatment=="modern":
						var paw:=bone_point(rig,"bip01 l hand");var row:={"phase":phase,"paw":[paw.x,paw.y,paw.z],"time":animation.length*phase}
						if clip=="Run":run_samples.append(row)
						else:gallop_samples.append(row)
				if clip=="Eat" and i==6:
					var skin:=points(mesh,rig,pink);var nose_y:=0.
					for index in nose_indices:nose_y+=skin[index].y
					nose_y/=nose_indices.size();check(nose_y>.0 and nose_y<.045,"Actual cat nose reaches feeding height")
				if clip=="Death" and phase==1. and treatment=="modern":check(bounds.size.y<.2,"Collapsed cat lies on its side")
				if treatment=="modern":envelope=bounds if first_envelope else envelope.merge(bounds);first_envelope=false
				samples.append({"treatment":treatment,"clip":clip,"phase":phase,"bounds":{"position":[bounds.position.x,bounds.position.y,bounds.position.z],"size":[bounds.size.x,bounds.size.y,bounds.size.z]}})
				if i==(10 if clip=="Run" else 6) and clip in ["Idle","Walk","Run","Attack","Eat","Death"]:
					await RenderingServer.frame_post_draw;var image:=viewport.get_texture().get_image();var occupied:=0
					for y in range(0,image.get_height(),5):
						for x in range(0,image.get_width(),5):
							if image.get_pixel(x,y).a>.1:occupied+=1
					check(occupied>150,"Actual Forward+ cat render contains visible skin");image.save_png(ProjectSettings.globalize_path(output+"/"+treatment+"-"+clip+".png"))
		model.queue_free();await process_frame
	check(run_samples.size()==21,"Measured exported 60Hz running trajectory")
	var speed:=absf(float(run_samples[5].paw[2])-float(run_samples[1].paw[2]))/(float(run_samples[5].time)-float(run_samples[1].time))
	check(absf(speed-1.8)<.08,"Actual imported stance-paw speed matches1.8m/s reference")
	check(gallop_samples.size()==81,"Measured short-stance gallop retains high-rate samples")
	var gallop_speed:=absf(float(gallop_samples[5].paw[2])-float(gallop_samples[1].paw[2]))/(float(gallop_samples[5].time)-float(gallop_samples[1].time))
	check(absf(gallop_speed-6.8)<.12,"Actual imported gallop stance matches6.8m/s reference")
	var report:={"checks":checks,"failures":failures,"assets":assets,"samples":samples,"run_stance_speed_mps":speed,"gallop_stance_speed_mps":gallop_speed,"run_samples":run_samples,"gallop_samples":gallop_samples,"renderer":RenderingServer.get_current_rendering_method(),
		"envelope":{"position":[envelope.position.x,envelope.position.y,envelope.position.z],"size":[envelope.size.x,envelope.size.y,envelope.size.z]},"recipe_sha256":FileAccess.get_sha256("res://../scripts/blender-prepare-cat.py"),"preparation_sha256":FileAccess.get_sha256(folder+"/preparation.json"),"test_sha256":FileAccess.get_sha256("res://Presentation/CatMotionTests.gd")}
	FileAccess.open(output+"/motion.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("CAT MOTION: ",checks," / ",failures," failures; ",samples.size()," complete skins; stance speed ",speed);quit(0 if failures==0 else 1)
