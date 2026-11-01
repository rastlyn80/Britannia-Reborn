extends SceneTree
## Actual source skins, muzzle trajectory, four hoof anchors and finite terrain.
const Visual=preload("res://Presentation/CreatureVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const INPUTS=["CervidActionTests.gd","CreatureVisual.gd","OstardVisual.gd","SkinGeometry.gd","HumanActions.gd","SourceMountContact.gd","AnimalPoseLibrary.gd","HumanHue.gd","OstardSurface.gdshader","FootContact.gd"]
var checks:=0
var failures:=0
var samples: Array=[]
var terrain: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<18:push_error(label)
func find(rig: Skeleton3D,name: String) -> int:
	for i in rig.get_bone_count():
		if str(rig.get_bone_name(i)).replace("_","")==name:return i
	return -1
func point(rig: Skeleton3D,name: String) -> Vector3:return rig.to_global(rig.get_bone_global_pose(find(rig,name)).origin)
func skin(mesh: MeshInstance3D,rig: Skeleton3D) -> PackedVector3Array:
	var matrices: Array[Transform3D]=[]
	for i in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(i)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(i))
		matrices.append(rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(i))
	var arrays:=mesh.mesh.surface_get_arrays(0);var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var joints: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var stride:=joints.size()/vertices.size();var result:=PackedVector3Array()
	for vertex in vertices.size():
		var p:=Vector3.ZERO
		for j in stride:p+=(matrices[joints[vertex*stride+j]]*vertices[vertex])*weights[vertex*stride+j]
		result.append(rig.to_global(p))
	return result
func difference(a: Image,b: Image) -> int:
	var count:=0
	for y in range(0,a.get_height(),3):
		for x in range(0,a.get_width(),3):
			if (a.get_pixel(x,y)-b.get_pixel(x,y)).get_luminance()>.02 or (b.get_pixel(x,y)-a.get_pixel(x,y)).get_luminance()>.02:count+=1
	return count
func run() -> void:
	var runtime: Dictionary={}
	for name in INPUTS:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var recipes: Dictionary={}
	for name in ["creature-cervid-actions.py","creature-humanoid-actions.py"]:recipes[name]=FileAccess.get_sha256("res://../scripts/"+name)
	var preparation_path:="res://local-art/creatures/deer/preparation.json";var prep_sha:=FileAccess.get_sha256(preparation_path)
	var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation_path))
	var folder:="res://../outputs/creatures/deer/gestures";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var viewport:=SubViewport.new();viewport.size=Vector2i(800,800);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;viewport.add_child(camera)
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(12.,.1,12.);collider.shape=shape;collider.position.y=-.05;ground.add_child(collider);viewport.add_child(ground)
	var assets: Dictionary={}
	for record: Dictionary in preparation.models:
		if record.status!="prepared":continue
		var path: String="res://local-art/creatures/"+str(record.kind)+"-modern.gltf";assets[record.kind]={"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import")}
		var actor:=Visual.new();actor.entry=record;viewport.add_child(actor);actor.rotation.y=-.65;actor.set_process(false);actor.set_physics_process(false);actor.contact.enabled=false
		var rig:=actor.skeleton;var mesh: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0]
		check(actor.contact.feet.size()==4,"All four source hooves have separate skin-supported contact records")
		actor.play("Idle",0.);actor.animator.seek(0.,true);actor.animator.pause();for frame in 2:await process_frame
		var baseline: Dictionary={}
		for side: String in ["l","r"]:
			for limb: String in ["hand","foot"]:
				var name:="bip01 "+side+" "+limb;baseline[name]=point(rig,name)
		var head:=point(rig,"bip01 head");var forward:=head-point(rig,"bip01 neck");forward.y=0.;forward=forward.normalized()
		var vertices:=skin(mesh,rig);var arrays:=mesh.mesh.surface_get_arrays(0);var joints: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var stride:=joints.size()/vertices.size()
		var head_vertices: Array[int]=[];var furthest:=-INF
		var height:=float(record.stats.original.height_m)
		for i in vertices.size():
			var influence:=0.
			for j in stride:
				var bind:=joints[i*stride+j];var bone:=mesh.skin.get_bind_bone(bind)
				if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
				if bone==find(rig,"bip01 head"):influence+=weights[i*stride+j]
			if influence>.5 and vertices[i].y<head.y+height*.05 and vertices[i].y>head.y-height*.2:head_vertices.append(i);furthest=maxf(furthest,forward.dot(vertices[i]))
		var muzzle: Array[int]=[]
		for i in head_vertices:
			if forward.dot(vertices[i])>furthest-height*.015:muzzle.append(i)
		check(not muzzle.is_empty(),"Actual weighted muzzle skin is identified separately from antlers")
		var framing:=Geometry.deformed_bounds(mesh,rig);var target:=framing.get_center()
		camera.size=float(record.stats.original.bind_diagonal_m)*1.1;camera.position=target+Vector3(height*.9,height*.8,height*1.8);camera.look_at(target)
		for clip: String in ["Attack2","Eat"]:
			actor.dead=false;actor.action_remaining=0.
			check(actor.receive_action({"protocol":"classic","action":6 if clip=="Attack2" else 3}) and actor.current_clip==clip and not actor.dead,"Native category selects its explicit living cervid replacement")
			actor.contact.enabled=false;actor.play(clip,0.);actor.animator.pause();var first: Image
			for frame in 13:
				var phase:=float(frame)/12.;actor.animator.seek(actor.animator.current_animation_length*phase,true);for settle in 2:await process_frame
				var box:=Geometry.deformed_bounds(mesh,rig);var positions:=skin(mesh,rig);var muzzle_height:=0.
				for i in muzzle:muzzle_height+=positions[i].y/maxi(1,muzzle.size())
				check(box.position.is_finite() and box.size.length()<height*2.5,"Actual cervid skin stays finite and bounded")
				check(absf(box.position.y)<.025,"Actual skin retains its support within25mm")
				check(actor.transform.origin.is_zero_approx(),"Authored action never changes native coordinates")
				var hoof_moves: Dictionary={}
				for name in baseline:
					var delta:=point(rig,name)-(baseline[name] as Vector3);hoof_moves[name]=[delta.x,delta.y,delta.z]
					check(Vector2(delta.x,delta.z).length()<.015 and absf(delta.y)<.025,"All four hoof anchors stay within15mm horizontal/25mm vertical: "+str([record.kind,clip,phase,name,delta]))
				for hoof: Dictionary in actor.contact.feet:check(absf(actor.contact.sole(hoof).y)<.025,"Each actual weighted hoof sole stays on the flat support, not only its bone marker")
				if clip=="Eat" and frame==6:check(muzzle_height>=-.025 and muzzle_height<.15,"Grazing lowers actual muzzle skin near the ground without penetration: "+str([record.kind,muzzle_height]))
				if clip=="Attack2" and frame==6:check(head.y-point(rig,"bip01 head").y>.08,"Head thrust visibly lowers the actual head")
				if frame in [0,3,6,9,12]:
					await RenderingServer.frame_post_draw;var picture:=viewport.get_texture().get_image();picture.convert(Image.FORMAT_RGBA8)
					if frame==0:first=picture
					if frame==6:check(difference(first,picture)>70,"Actual cervid pixels show a distinct gesture")
					picture.save_png(ProjectSettings.globalize_path(folder+"/"+str(record.kind)+"-"+clip+"-"+str(frame)+".png"))
				samples.append({"kind":record.kind,"clip":clip,"phase":phase,"floor_y":box.position.y,"muzzle_y":muzzle_height,"hoof_moves":hoof_moves})
		actor.contact.enabled=true;actor.set_physics_process(true)
		for slope in [Vector2.ZERO,Vector2(.06,0.),Vector2(0.,.06)]:
			ground.rotation=Vector3(slope.x,0.,slope.y)
			for clip: String in ["Attack2","Eat"]:
				for phase in [0.,.5,1.]:
					actor.current_clip=clip;actor.play(clip,0.);actor.animator.pause()
					for settle in 45:actor.animator.seek(actor.animator.current_animation_length*phase,true);await physics_frame;await process_frame
					var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3.UP,Vector3.DOWN,1));check(not hit.is_empty(),"Cervid support uses a real finite collider")
					if hit.is_empty():continue
					var gap:=INF
					for p in skin(mesh,rig):gap=minf(gap,hit.normal.dot(p-hit.position))
					check(gap>-.025 and gap<.025,"Actual cervid skin meets the sampled plane within25mm")
					for hoof: Dictionary in actor.contact.feet:check(absf(hit.normal.dot(actor.contact.sole(hoof)-hit.position))<.05,"Each actual weighted hoof sole retains finite-plane support within50mm")
					check(actor.position.is_zero_approx(),"Terrain fitting keeps native coordinates fixed")
					terrain.append({"kind":record.kind,"clip":clip,"phase":phase,"slope":[slope.x,slope.y],"skin_plane_gap":gap})
		actor.free();ground.rotation=Vector3.ZERO
	for name in INPUTS:check(runtime[name]==FileAccess.get_sha256("res://Presentation/"+name),"Cervid runtime remains unchanged during rendering")
	for name in recipes:check(recipes[name]==FileAccess.get_sha256("res://../scripts/"+name),"Cervid recipe remains unchanged during rendering")
	check(prep_sha==FileAccess.get_sha256(preparation_path),"Cervid preparation remains unchanged during rendering")
	var file:=FileAccess.open(folder+"/validation.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"assets":assets,"samples":samples,"terrain_samples":terrain,"runtime_sha256":runtime,"recipe_sha256":recipes,"preparation_sha256":prep_sha,"scope":"Authored head strike/grazing actual skin, muzzle/four hoof paths, rendered pixel changes and finite collider fitting. Not original choreography or arbitrary terrain proof."},"  "));file.close()
	print("CERVID ACTIONS: ",checks," checks / ",failures," failures; ",samples.size()," skin samples");quit(1 if failures else 0)
