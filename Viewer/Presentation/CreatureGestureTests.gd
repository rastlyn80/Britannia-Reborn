extends SceneTree
## Render and measure the added orc gestures on their actual source rigs.
const Visual=preload("res://Presentation/CreatureVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const INPUTS=["CreatureGestureTests.gd","CreatureVisual.gd","OstardVisual.gd","SkinGeometry.gd","HumanActions.gd","SourceMountContact.gd","AnimalPoseLibrary.gd","HumanHue.gd","OstardSurface.gdshader","FootContact.gd"]
var checks:=0
var failures:=0
var samples: Array=[]
var terrain: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<16:push_error(label)
func find(rig: Skeleton3D,name: String) -> int:
	for i in rig.get_bone_count():
		if str(rig.get_bone_name(i)).replace("_","")==name.replace("_",""):return i
	return -1
func point(rig: Skeleton3D,name: String) -> Vector3:return rig.to_global(rig.get_bone_global_pose(find(rig,name)).origin)
func difference(a: Image,b: Image) -> int:
	var total:=0
	for y in range(0,a.get_height(),3):
		for x in range(0,a.get_width(),3):
			var p:=a.get_pixel(x,y);var q:=b.get_pixel(x,y)
			if Vector4(p.r-q.r,p.g-q.g,p.b-q.b,p.a-q.a).length()>.06:total+=1
	return total
func plane_gap(mesh: MeshInstance3D,rig: Skeleton3D,origin: Vector3,normal: Vector3) -> float:
	var matrices: Array[Transform3D]=[]
	for bind in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(bind)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
		matrices.append(rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
	var arrays:=mesh.mesh.surface_get_arrays(0);var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
	var stride:=bones.size()/points.size();var minimum:=INF
	for vertex in points.size():
		var position:=Vector3.ZERO
		for influence in stride:position+=(matrices[bones[vertex*stride+influence]]*points[vertex])*weights[vertex*stride+influence]
		minimum=minf(minimum,normal.dot(rig.to_global(position)-origin))
	return minimum
func run() -> void:
	var hashes: Dictionary={}
	for file in INPUTS:hashes[file]=FileAccess.get_sha256("res://Presentation/"+file)
	var recipe_sha:=FileAccess.get_sha256("res://../scripts/creature-humanoid-actions.py")
	var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/orcs/preparation.json"))
	var folder:="res://../outputs/creatures/orcs/gestures";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var viewport:=SubViewport.new();viewport.size=Vector2i(800,800);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;viewport.add_child(camera)
	var ground:=StaticBody3D.new();var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(20.,.1,20.);collision.shape=shape;collision.position.y=-.05;ground.add_child(collision);viewport.add_child(ground)
	var assets: Dictionary={}
	for record: Dictionary in preparation.models:
		var asset_path: String="res://local-art/creatures/"+str(record.kind)+"-modern.gltf"
		assets[record.kind]={"asset_sha256":FileAccess.get_sha256(asset_path),"import_sha256":FileAccess.get_sha256(asset_path+".import")}
		var actor:=Visual.new();actor.entry=record;viewport.add_child(actor);actor.set_process(false);actor.set_physics_process(false);actor.contact.enabled=false;actor.rotation.y=-.8
		var rig: Skeleton3D=actor.skeleton;var mesh: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0]
		actor.play("Idle",0.);actor.animator.seek(0.,true);actor.animator.pause()
		for frame in 2:await process_frame
		var baseline: Dictionary={}
		for name in ["bip01 l foot","bip01 r foot","bip01 l hand","bip01 r hand","bip01 head"]:baseline[name]=point(rig,name)
		var grip_poses: Dictionary={}
		var wrist_poses: Dictionary={}
		for side: String in ["l","r"]:grip_poses[side]=rig.get_bone_pose(find(rig,"cp_grasp_"+side+"hand"))
		for side: String in ["l","r"]:wrist_poses[side]=rig.get_bone_pose(find(rig,"bip01 "+side+" hand"))
		var attack_paths: Dictionary={}
		var original_transform:=actor.transform
		for category in [2,5,14]:
			actor.action_remaining=0.;actor.dead=false
			check(actor.receive_action({"protocol":"new","type":category}),"Explicit additional native action category is consumed")
			check(actor.current_clip==str(record.new_action_categories[str(category)]),"Additional native action uses its declared replacement")
		actor.contact.enabled=false
		var height:=float(record.stats.original.height_m)
		camera.size=height*1.4;camera.position=Vector3(height*.8,height*.9,height*2.);camera.look_at(Vector3(0.,height*.5,0.))
		for clip: String in ["Cast","Pillage","Attack2","Attack3"]:
			check(actor.animator.has_animation(clip),"Prepared gesture exists: "+str(record.kind)+" / "+clip)
			for protocol: String in ["classic","new"]:
				if clip=="Pillage" and protocol=="new":continue
				actor.action_remaining=0.;actor.dead=false
				if clip.begins_with("Attack") and protocol=="new":continue
				check(actor.receive_action({"protocol":protocol,"action":int({"Cast":12,"Pillage":11,"Attack2":5,"Attack3":6}[clip]),"type":11}),"Actual renderer accepts "+clip+" / "+protocol)
			actor.contact.enabled=false
			actor.play(clip,0.);actor.animator.pause()
			var striking_hand: Array[Vector3]=[]
			var hand_travel:=0.;var head_drop:=0.;var first: Image
			for frame in 21:
				var phase:=float(frame)/20.;actor.animator.seek(actor.animator.current_animation_length*phase,true)
				for settle in 2:await process_frame
				var box:=Geometry.deformed_bounds(mesh,rig)
				var foot_moves: Dictionary={}
				check(box.position.is_finite() and box.size.is_finite() and box.size.length()<height*2.,"Gesture skin remains finite and bounded")
				check(absf(box.position.y)<.025,"Gesture skin retains flat support within25mm")
				check(actor.transform.is_equal_approx(original_transform),"Gesture does not move the native entity transform")
				for side: String in ["l","r"]:
					var hand:="bip01 "+side+" hand";hand_travel=maxf(hand_travel,point(rig,hand).distance_to(baseline[hand]))
					if clip!="Pillage" or record.get("authored_replacements",{}).has("Pillage"):
						var foot:="bip01 "+side+" foot";var movement:=point(rig,foot)-(baseline[foot] as Vector3)
						foot_moves[side]=[movement.x,movement.y,movement.z]
						check(Vector2(movement.x,movement.z).length()<.015 and absf(movement.y)<.025,"Authored gesture keeps the actual stance foot within15mm horizontal/25mm vertical")
					var hand_index:=find(rig,hand);var grasp_index:=find(rig,"cp_grasp_"+side+"hand")
					check(grasp_index>=0 and rig.get_bone_parent(grasp_index)==hand_index,"Original item-grip attachment stays on its hand")
					check(rig.get_bone_pose(grasp_index).is_equal_approx(grip_poses[side]),"Original prop grip keeps its local hand offset and orientation")
					if clip!="Pillage" or record.get("authored_replacements",{}).has("Pillage"):check(rig.get_bone_pose(hand_index).is_equal_approx(wrist_poses[side]),"Authored gesture retains the source wrist pose relative to the forearm")
				var drop: float=(baseline["bip01 head"] as Vector3).y-point(rig,"bip01 head").y;head_drop=maxf(head_drop,drop)
				if clip.begins_with("Attack") and frame in [5,10]:striking_hand.append(point(rig,"bip01 r hand"))
				if frame in [0,5,10,15,20]:
					await RenderingServer.frame_post_draw
					var picture:=viewport.get_texture().get_image();picture.convert(Image.FORMAT_RGBA8)
					if frame==0:first=picture
					if frame==10:check(difference(first,picture)>100,"Actual rendered gesture differs visibly from its starting pose")
					picture.save_png(ProjectSettings.globalize_path(folder+"/"+str(record.kind)+"-"+clip+"-"+str(frame)+".png"))
				samples.append({"kind":record.kind,"clip":clip,"phase":phase,"floor_y":box.position.y,"head_drop":drop,"foot_moves":foot_moves})
			check(hand_travel>.08,"Measured hand travel exceeds8cm; gesture is not a held idle")
			if clip.begins_with("Attack"):attack_paths[clip]=striking_hand
			if clip=="Pillage" and record.get("authored_replacements",{}).has("Pillage"):check(head_drop>.2,"Ground-slap/pillage category visibly crouches")
		check((attack_paths.Attack2[0] as Vector3).distance_to(attack_paths.Attack3[0])>.1,"Actual source rig has distinct overhead and sweeping windups")
		check((attack_paths.Attack2[0] as Vector3).y>(attack_paths.Attack2[1] as Vector3).y+.1,"Overhead strike descends at least10cm into impact")
		var source_strike: Array[Vector3]=[]
		actor.play("Attack",0.);actor.animator.pause()
		for phase in [.25,.5]:
			actor.animator.seek(actor.animator.current_animation_length*phase,true)
			for settle in 2:await process_frame
			source_strike.append(point(rig,"bip01 r hand"))
		for clip: String in ["Attack2","Attack3"]:
			var separation: float=maxf((attack_paths[clip][0] as Vector3).distance_to(source_strike[0]),(attack_paths[clip][1] as Vector3).distance_to(source_strike[1]))
			check(separation>.1,"Added melee strike has a measured hand path distinct from the preserved source attack")
		actor.contact.enabled=true;actor.set_physics_process(true)
		for slope in [Vector2.ZERO,Vector2(.08,0.),Vector2(0.,.06)]:
			ground.rotation=Vector3(slope.x,0.,slope.y)
			for clip: String in ["Cast","Pillage","Attack2","Attack3"]:
				for phase in [0.,.5,1.]:
					actor.current_clip=clip;actor.play(clip,0.);actor.animator.pause()
					for settle in 45:
						actor.animator.seek(actor.animator.current_animation_length*phase,true);await physics_frame;await process_frame
					var hit:=actor.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3.UP,Vector3.DOWN,1))
					check(not hit.is_empty(),"Gesture terrain collider is actually sampled")
					if hit.is_empty():continue
					var gap:=plane_gap(mesh,rig,hit.position,hit.normal)
					check(gap>-.025 and gap<.025,"Actual gesture skin meets the sampled support plane within25mm: "+str(record.kind)+" / "+clip)
					var supported: bool=not actor.contact.errors.is_empty()
					for error: float in actor.contact.errors:supported=supported and is_finite(error) and error<.05
					check(supported,"Actual gesture retains a measured stance sole within50mm")
					check(actor.transform.is_equal_approx(original_transform),"Gesture terrain fitting preserves native coordinates")
					terrain.append({"kind":record.kind,"clip":clip,"phase":phase,"slope":[slope.x,slope.y],"skin_plane_gap":gap,"stance_errors":actor.contact.errors.duplicate()})
		check(FileAccess.get_sha256(asset_path)==assets[record.kind].asset_sha256 and FileAccess.get_sha256(asset_path+".import")==assets[record.kind].import_sha256,"Gesture asset and import settings stayed unchanged during the sweep")
		actor.free()
	for file in INPUTS:check(hashes[file]==FileAccess.get_sha256("res://Presentation/"+file),"Gesture runtime stayed unchanged throughout the sweep")
	check(recipe_sha==FileAccess.get_sha256("res://../scripts/creature-humanoid-actions.py"),"Gesture authoring recipe stayed unchanged throughout the sweep")
	var output:=FileAccess.open(folder+"/validation.json",FileAccess.WRITE);output.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"assets":assets,"samples":samples,"terrain_samples":terrain,"runtime_sha256":hashes,"recipe_sha256":recipe_sha,"scope":"Actual imported orc casts/ground-slap/overhead/sweeping categories, rendered gesture change, stance stability, source grip hierarchy and finite collision-plane fitting. Authored approximations; source Stomp reuse remains explicit. Native action packets and arbitrary terrain are separate."},"\t"));output.close()
	print("ORC GESTURES: ",checks-failures," / ",checks,"; ",samples.size()," skinned samples");quit(1 if failures else 0)
