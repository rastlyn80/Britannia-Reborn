extends SceneTree
## Measured end-joint paths on the actual source rig, plus actual rendered poses.
const Visual=preload("res://Presentation/CreatureVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func tip(rig: Skeleton3D,side: String) -> Vector3:
	var bone:=rig.find_bone("bip01 "+side+" toe02");assert(bone>=0)
	return rig.to_global(rig.get_bone_global_pose(bone).origin)
func travel(points: Array) -> float:
	var result:=0.
	for point: Vector3 in points:result=maxf(result,point.distance_to(points[0]))
	return result
func run() -> void:
	var runtime: Dictionary={}
	for name in ["CephalopodGestureTests.gd","CreatureVisual.gd","CreatureCutoutSurface.gdshader","SkinGeometry.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var recipe_sha:=FileAccess.get_sha256("res://../scripts/creature-cephalopod.py")
	var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/krakens/preparation.json"));var record: Dictionary=preparation.models[0]
	var asset:="res://local-art/creatures/krakens_kraken-modern.gltf";var asset_sha:=FileAccess.get_sha256(asset);var import_sha:=FileAccess.get_sha256(asset+".import")
	var output:=ProjectSettings.globalize_path("res://../outputs/creatures/krakens/gestures");DirAccess.make_dir_recursive_absolute(output)
	var viewport:=SubViewport.new();viewport.size=Vector2i(768,640);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=12.;camera.position=Vector3(9.,7.,13.);viewport.add_child(camera);camera.look_at(Vector3.ZERO)
	var actor:=Visual.new();actor.entry=record;viewport.add_child(actor);actor.set_process(false);actor.set_physics_process(false)
	var rig: Skeleton3D=actor.skeleton;var mesh: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0]
	var paths: Dictionary={};var samples: Array=[]
	for clip in ["Attack","Attack2","Attack3","Cast"]:
		var left: Array=[];var right: Array=[]
		for frame in 17:
			actor.play(clip,0.);actor.animator.seek(actor.animator.get_animation(clip).length*float(frame)/16.,true);actor.animator.pause()
			await process_frame;rig.force_update_all_bone_transforms()
			var l:=tip(rig,"l");var r:=tip(rig,"r");left.append(l);right.append(r)
			var bounds:=Geometry.deformed_bounds(mesh,rig)
			check(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length()<22.,"Actual gesture skin remains finite and bounded")
			check(actor.global_position.is_zero_approx() and actor.model.to_local(rig.global_position).is_zero_approx(),"Gesture never changes native coordinates or aquatic waterline")
			samples.append({"clip":clip,"phase":float(frame)/16.,"left":[l.x,l.y,l.z],"right":[r.x,r.y,r.z]})
			if frame in [0,8,16]:
				for settle in 2:await process_frame
				await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png(output+"/"+clip+"-%02d.png"%frame)
		paths[clip]={"l":left,"r":right}
		if clip!="Attack":
			check(left[0].distance_to(left[-1])<.002 and right[0].distance_to(right[-1])<.002,"Authored gesture returns both feeding tips to its source idle pose")
	check(travel(paths.Attack2.l)>travel(paths.Attack2.r)*1.2,"Left strike has a physically distinct leading left tentacle")
	check(travel(paths.Attack3.r)>travel(paths.Attack3.l)*1.2,"Right strike has a physically distinct leading right tentacle")
	check(travel(paths.Cast.l)>.15 and travel(paths.Cast.r)>.15,"Both feeding tentacles visibly charge and release during casting")
	for pair in [["Attack","Attack2"],["Attack","Attack3"],["Attack2","Attack3"],["Attack","Cast"]]:
		var distance:=0.
		for frame in 17:
			for side in ["l","r"]:distance+=(paths[pair[0]][side][frame] as Vector3).distance_to(paths[pair[1]][side][frame])
		check(distance/34.>.15,"Actual normalized tip paths differ: "+pair[0]+" / "+pair[1])
	for name in runtime:check(runtime[name]==FileAccess.get_sha256("res://Presentation/"+name),"Runtime remains unchanged during gesture validation")
	check(recipe_sha==FileAccess.get_sha256("res://../scripts/creature-cephalopod.py") and asset_sha==FileAccess.get_sha256(asset) and import_sha==FileAccess.get_sha256(asset+".import"),"Gesture recipe and exact skin/import remain unchanged")
	var file:=FileAccess.open(output+"/validation.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"runtime_sha256":runtime,"recipe_sha256":recipe_sha,"asset_sha256":asset_sha,"import_sha256":import_sha,"renderer":RenderingServer.get_current_rendering_method(),"samples":samples},"  "));file.close()
	actor.free();print("CEPHALOPOD GESTURES: ",checks," checks / ",failures," failures");quit(1 if failures else 0)
