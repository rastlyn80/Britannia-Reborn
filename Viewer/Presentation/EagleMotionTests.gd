extends SceneTree
## Inspect every material's actual imported skin, source flight and new poses.
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<25:push_error(label)
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
func run() -> void:
	var folder:="res://local-art/eagle";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+"/preparation.json"));var output:="res://../outputs/creatures/eagle-trial";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var viewport:=SubViewport.new();viewport.size=Vector2i(1000,750);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.001;viewport.add_child(camera)
	var samples: Array=[];var assets: Dictionary={};var envelope:=AABB();var first_envelope:=true;var idle_width:=0.;var fly_width:=0.;var beak_idle:=INF;var beak_eat:=INF;var sole_max:=0.
	for treatment: String in ["source","modern"]:
		var path:=folder+"/eagle-"+treatment+".glb";assets[treatment]={"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import")}
		check(assets[treatment].asset_sha256==prep.treatments[treatment].asset_sha256,"Exact recipe output "+treatment)
		var model: Node3D=load(path).instantiate();viewport.add_child(model);var external:=model.transform
		var rig: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0];var mesh: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0];var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0]
		check(rig.get_bone_count()==24,"All donor bones and asymmetric wing hierarchy retained")
		var valid:=true;var triangles:=0;var eyes:=0;var beak:=-1;var claws:=-1
		for surface in mesh.mesh.get_surface_count():
			var arrays:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var stride:=weights.size()/vertices.size();triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
			valid=valid and stride==8
			for i in vertices.size():
				var total:=0.
				for j in stride:total+=weights[i*stride+j];valid=valid and weights[i*stride+j]>=0. and is_finite(weights[i*stride+j])
				valid=valid and absf(total-1.)<.0001
			var material:=mesh.get_active_material(surface) as StandardMaterial3D
			if material.resource_name.begins_with("EagleEye"):eyes+=1
			if material.resource_name=="EagleBeak":beak=surface
			if material.resource_name=="EagleClaws":claws=surface
			if treatment=="modern":mesh.set_surface_override_material(surface,preload("res://Presentation/CreatureEagleMaterial.gd").build(material,0))
		check(valid,"Every surface retains finite normalized eight-influence skin")
		check(triangles==int(prep.treatments[treatment].triangles),"Actual triangle inventory")
		check(beak>=0 and claws>=0 and eyes==(3 if treatment=="modern" else 0),"Four donor regions and added fixed eye surfaces remain distinguishable")
		var names: Array=prep.clips.keys()
		for clip: String in names:
			check(player.has_animation(clip),"Declared eagle category exists: "+clip)
			if not player.has_animation(clip):continue
			var animation:=player.get_animation(clip);animation.loop_mode=Animation.LOOP_NONE;player.play(clip,0.);player.pause()
			check(absf(animation.length-float(prep.clips[clip].duration))<.002,"Declared duration preserved: "+clip)
			var first: Array[Transform3D]=[];var root_low:=INF;var root_high:=-INF
			for i in 25:
				var phase:=float(i)/24.;player.seek(animation.length*phase,true);for frame in 2:await process_frame
				var bounds:=Geometry.deformed_bounds(mesh,rig);check(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length()>.2 and bounds.size.length()<2.6,"Complete eagle skin stays finite/bounded")
				var poses_finite:=true
				for b in rig.get_bone_count():
					var pose:=rig.get_bone_global_pose(b);poses_finite=poses_finite and pose.origin.is_finite() and pose.basis.is_finite() and pose.basis.determinant()>.01
					if i==0:first.append(pose)
				check(poses_finite,"All source/packed bones remain finite with positive nonzero volume")
				check(model.transform.is_equal_approx(external),"Actions leave external native entity transform unchanged")
				var root_point:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("Bone")).origin);root_low=minf(root_low,root_point.y);root_high=maxf(root_high,root_point.y)
				if treatment=="modern":
					check(bounds.position.y>-.004,"Actual modern skin remains above the support plane: "+clip)
					if clip in ["Fly","AirIdle","Run"]:check(bounds.position.y>.07,"Full-cycle constant flight clearance survives import")
					var soles:=points(mesh,rig,claws);var low:=INF
					for p in soles:low=minf(low,p.y)
					if clip in ["Idle","Eat","Attack","Attack2","Hit","Fidget","Alert"]:
						sole_max=maxf(sole_max,absf(low));check(low>-.004 and low<.008,"Real claw surface stays planted; wings do not prop up the actor")
					if clip=="Idle":idle_width=maxf(idle_width,bounds.size.x)
					if clip=="Run":fly_width=maxf(fly_width,bounds.size.x)
					if clip in ["Idle","Eat"]:
						# Beak material also includes yellow shins; only the forward
						# quarter of its actual skin is the feeding beak.
						var skin:=points(mesh,rig,beak);var front:=-INF
						for p in skin:front=maxf(front,p.z)
						var nose:=INF
						for p in skin:
							if p.z>front-.015:nose=minf(nose,p.y)
						if clip=="Idle":beak_idle=minf(beak_idle,nose)
						else:beak_eat=minf(beak_eat,nose)
					if i==24 and bool(prep.clips[clip].loop):
						var continuous:=true
						for b in rig.get_bone_count():
							var last:=rig.get_bone_global_pose(b);continuous=continuous and last.origin.distance_to(first[b].origin)<.001 and last.basis.orthonormalized().get_rotation_quaternion().angle_to(first[b].basis.orthonormalized().get_rotation_quaternion())<.01
						check(continuous,"Authored/closed eagle loop matches: "+clip)
					if i==24 and "Death" in clip:
						check(bounds.size.y<.22,"Cadaver lies down instead of remaining an upright bird")
						model.set_meta("corpse_body",5);model.set_meta("native_hue",0);model.set_meta("death_clip",clip)
						var frozen:=preload("res://Presentation/CorpseModels.gd").freeze(model)
						check(frozen!=null,"Static corpse accepts all seven eagle skin surfaces")
						if frozen:
							var corpse_bounds: AABB=frozen.get_meta("corpse_bounds");check(corpse_bounds.size.distance_to(bounds.size)<.0003,"Cadaver preserves final actual skinned shape");check(absf(corpse_bounds.position.y)<.0001,"Static corpse rests on its plane");frozen.free()
					envelope=bounds if first_envelope else envelope.merge(bounds);first_envelope=false
				samples.append({"treatment":treatment,"clip":clip,"phase":phase,"minimum_y":bounds.position.y,"size":[bounds.size.x,bounds.size.y,bounds.size.z]})
				if i==12:
					camera.size=bounds.size.length()*1.1;camera.position=bounds.get_center()+Vector3(2.,1.2,2.5);camera.look_at(bounds.get_center())
					for frame in 3:await process_frame
					await RenderingServer.frame_post_draw;viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(output+"/"+treatment+"-"+clip+".png"))
			if treatment=="modern" and clip in ["Fly","AirIdle","Run"]:check(root_high-root_low<.06,"Flight torso does not bob with the lowest feather")
		model.queue_free();await process_frame
	check(idle_width<fly_width*.4,"Perched wings tuck inside full source flight span")
	check(beak_idle-beak_eat>.12 and beak_eat<.09 and beak_eat>.0,"Actual feeding beak lowers near the plane without dragging planted claws")
	var runtime: Dictionary={}
	for name: String in ["SkinGeometry.gd","CorpseModels.gd","CreatureEagleMaterial.gd","CreatureEagleSurface.gdshader","ItemStudio.gd"]:runtime["res://Presentation/"+name]=FileAccess.get_sha256("res://Presentation/"+name)
	var report:={"checks":checks,"failures":failures,"samples":samples,"assets":assets,"standing_sole_max_m":sole_max,"perched_width_m":idle_width,"flight_span_m":fly_width,"idle_beak_y":beak_idle,"feeding_beak_y":beak_eat,"renderer":RenderingServer.get_current_rendering_method(),"envelope":{"position":[envelope.position.x,envelope.position.y,envelope.position.z],"size":[envelope.size.x,envelope.size.y,envelope.size.z]},"runtime_sha256":runtime,"preparation_sha256":FileAccess.get_sha256(folder+"/preparation.json"),"recipe_sha256":FileAccess.get_sha256("res://../scripts/blender-prepare-eagle.py"),"test_sha256":FileAccess.get_sha256("res://Presentation/EagleMotionTests.gd")}
	FileAccess.open(output+"/motion.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "));print("EAGLE MOTION: ",checks," / ",failures," failures; ",samples.size()," skins; soles ",sole_max,"; beak ",beak_eat);quit(1 if failures else 0)
