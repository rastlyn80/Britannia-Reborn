extends SceneTree
## Both complete donor skins, exact rig motion, positive hop and source timing.
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Support=preload("res://Presentation/RabbitGroundSupport.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<20:push_error(label)
func run() -> void:
	var preparation:="res://local-art/rabbit/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation));var source: Dictionary={};var assets: Dictionary={};var samples: Array=[];var gaits: Dictionary={};var envelope:=AABB();var first_bound:=true;var airborne:=0;var maximum_relative_error:=0.;var minimum_rotation_dot:=1.
	for treatment: String in ["source","modern"]:
		var path:="res://local-art/rabbit/rabbit-"+treatment+".glb";var model: Node3D=load(path).instantiate();root.add_child(model)
		var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0];var meshes:=model.find_children("*","MeshInstance3D",true,false);var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0];var body:=model.find_child("Rabbit",true,false) as MeshInstance3D
		check(rig.get_bone_count()==37 and meshes.size()==2 and body!=null,"Original37 bones and separate body/fur skins survive")
		var helper:=Support.new();rig.add_child(helper);helper.active=false;helper.enabled=false;helper.configure(body,true)
		check(helper.feet.size()==4 and helper.stride==8,"All four real paw chains use complete eight-influence body skin")
		var triangles:=0;var weights_valid:=true;var normal_maps:=0;var alpha_maps:=0
		for mesh: MeshInstance3D in meshes:
			for surface in mesh.mesh.get_surface_count():
				var arrays:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX];var stride:=weights.size()/vertices.size();triangles+=(indices.size() if not indices.is_empty() else vertices.size())/3
				weights_valid=weights_valid and stride==8
				for i in vertices.size():
					var total:=0.
					for j in stride:total+=weights[i*stride+j];weights_valid=weights_valid and weights[i*stride+j]>=0. and is_finite(weights[i*stride+j])
					weights_valid=weights_valid and absf(total-1.)<.0001
				var material:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
				if material.normal_texture!=null:normal_maps+=1
				if material.albedo_texture!=null:alpha_maps+=1
		check(weights_valid,"Every actual vertex has finite normalized eight-influence weights")
		check(triangles==int(prep.treatments[treatment].triangles.Rabbit)+int(prep.treatments[treatment].triangles.Fur),"Exact declared body plus original fur triangle inventory")
		check(normal_maps==1 and alpha_maps==2,"Artist's real normal and both alpha/albedo maps survive")
		var maximum_gap:=0.;var maximum_diagonal:=0.
		for clip: String in prep.clips:
			check(player.has_animation(clip),"Declared source/adapted category exists:"+clip)
			if not player.has_animation(clip):continue
			var duration: float=player.get_animation(clip).length
			check(absf(duration-float(prep.treatments[treatment].clips[clip].duration))<.0001,"Source or declared adapted timing retained:"+clip)
			var first_bones: Array=[];var gait: Array=[]
			for i in 33:
				var phase:=float(i)/32.;player.play(clip,0.);player.seek(duration*phase,true);player.pause();await process_frame;await process_frame
				var bounds:=Geometry.deformed_bounds(meshes[0],rig)
				for j in range(1,meshes.size()):bounds=bounds.merge(Geometry.deformed_bounds(meshes[j],rig))
				check(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length()>.2 and bounds.size.length()<1.5,"Complete body/fur skin remains finite and bounded")
				maximum_diagonal=maxf(maximum_diagonal,bounds.size.length());maximum_gap=maxf(maximum_gap,absf(bounds.position.y))
				var bones: Array=[];var rotations: Array=[]
				for bone in rig.get_bone_count():bones.append(rig.to_global(rig.get_bone_global_pose(bone).origin));rotations.append(rig.get_bone_global_pose(bone).basis.orthonormalized().get_rotation_quaternion())
				if i==0:first_bones=bones.duplicate()
				if i==32 and bool(prep.clips[clip].loop):
					var gap:=0.
					for bone in bones.size():gap=maxf(gap,bones[bone].distance_to(first_bones[bone]))
					check(gap<.001,"Loop closes on all original bones within1mm:"+clip)
				var key:=clip+"/"+str(i)
				if treatment=="source":source[key]={"bones":bones,"rotations":rotations,"lowest":bounds.position.y}
				else:
					check(bounds.position.y>-.004,"Modern complete skin avoids penetration within4mm:"+clip+"/"+str(phase))
					var reference: Dictionary=source[key];var shift: Vector3=bones[0]-reference.bones[0];var relative:=true;var rotated:=true
					for bone in bones.size():
						var error: float=(bones[bone]-reference.bones[bone]-shift).length();var dot: float=absf(rotations[bone].dot(reference.rotations[bone]));maximum_relative_error=maxf(maximum_relative_error,error);minimum_rotation_dot=minf(minimum_rotation_dot,dot);relative=relative and error<.0001;rotated=rotated and dot>.99999
					var limit:=.12 if clip in ["Walk","Run"] else .0001
					check(relative and absf(shift.x)<.0001 and absf(shift.z)<limit and shift.y>-.0001,"Both roots shift uniformly; original relative skeleton retained")
					check(rotated,"Every original source/declared joint orientation retained")
					if clip in ["Run","Walk","Jump"] and float(reference.lowest)>.03:
						airborne+=1;check(absf(shift.y)<.001 and bounds.position.y>.025,"Genuine positive source airborne hop remains unpinned")
					envelope=bounds if first_bound else envelope.merge(bounds);first_bound=false
					if clip in ["Run","Walk"]:
						var paws: Array=[]
						for foot: Dictionary in helper.feet:paws.append(helper.sole(foot))
						gait.append({"time":duration*phase,"paws":paws})
				samples.append({"treatment":treatment,"clip":clip,"phase":phase,"lowest_vertex":bounds.position.y,"height":bounds.size.y,"diagonal":bounds.size.length()})
			if treatment=="modern" and clip in ["Run","Walk"]:
				var speeds: Array=[];var rows: Array=[]
				for i in range(1,gait.size()):
					for foot in helper.feet.size():
						var a: Vector3=gait[i-1].paws[foot];var b: Vector3=gait[i].paws[foot];var dt: float=gait[i].time-gait[i-1].time
						if a.y<.012 and b.y<.012 and absf(a.y-b.y)<.004:
							var speed:=absf(b.z-a.z)/dt;speeds.append(speed);rows.append({"foot":foot,"start":gait[i-1].time,"speed_z":speed})
				check(not speeds.is_empty(),"Actual skin supplies planted paw velocity samples:"+clip);speeds.sort();gaits[clip]={"median_stance_speed_mps":speeds[speeds.size()/2] if not speeds.is_empty() else 0.,"stance_samples":rows,"paw_poses":gait}
		assets[treatment]={"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import"),"maximum_skin_diagonal_m":maximum_diagonal};model.free()
	check(airborne>=20,"Full hop audit includes genuine airborne Walk/Run/Jump samples")
	var output:="res://../outputs/creatures/rabbit-trial";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var report:={"checks":checks,"failures":failures,"samples":samples,"assets":assets,"gaits":gaits,"airborne_cases":airborne,"maximum_relative_pose_error_m":maximum_relative_error,"minimum_rotation_dot":minimum_rotation_dot,"envelope":{"position":[envelope.position.x,envelope.position.y,envelope.position.z],"size":[envelope.size.x,envelope.size.y,envelope.size.z]},"preparation_sha256":FileAccess.get_sha256(preparation),"recipe_sha256":FileAccess.get_sha256("res://../scripts/blender-prepare-rabbit.py"),"gait_recipe_sha256":FileAccess.get_sha256("res://../scripts/creature-rabbit-gaits.py"),"test_sha256":FileAccess.get_sha256("res://Presentation/RabbitMotionTests.gd"),"scope":"Actual complete source/refined body plus fur skins, all37 source joint orientations/relative positions, declared category timing/loops, normalized8-weight vertices, actual source normals/alphas and positive hop preservation. Common longitudinal gait root adaptation is explicit. Paw stance velocities measured for calibration. No native server, terrain/avatar/hue, final anatomy or public-distribution acceptance."}
	FileAccess.open(output+"/motion.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("RABBIT MOTION: ",checks," / ",failures," failures; ",samples.size()," complete skins; ",airborne," airborne cases");quit(1 if failures else 0)
