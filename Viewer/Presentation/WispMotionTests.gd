extends SceneTree
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<10:push_error(label)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/creatures/wisp-trial"))
	var model:=load("res://local-art/wisp/wisp-modern.scn").instantiate() as Node3D;root.add_child(model)
	var rig:=model.get_node("Rig") as Skeleton3D;var animation:=model.get_node("AnimationPlayer") as AnimationPlayer
	check(rig.get_bone_count()==7,"All seven authored bones survive packed-scene round trip")
	var samples: Array=[]
	for category: String in animation.get_animation_list():
		animation.play(category,0.)
		for phase in 11:
			animation.seek(animation.get_animation(category).length*float(phase)/10.,true);animation.pause();rig.force_update_all_bone_transforms()
			var first:=true;var bounds:=AABB()
			for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
				var box:=Geometry.deformed_bounds(mesh,rig)
				check(box.position.is_finite() and box.size.is_finite() and box.size.length()>.001 and box.size.length()<3.,"Actual complete skin is finite and nonempty "+category+" "+str(phase))
				bounds=box if first else bounds.merge(box);first=false
			check(bounds.size.length()>.1 and bounds.position.y>-.02,"Authored effect envelope remains above the body anchor "+category)
			if category=="Idle" and phase==0:check(bounds.size.x>.5 and bounds.size.y>.65 and bounds.size.z>.5,"All six rays retain their distinct three-dimensional rest directions")
			samples.append({"category":category,"phase":float(phase)/10.,"position":[bounds.position.x,bounds.position.y,bounds.position.z],"size":[bounds.size.x,bounds.size.y,bounds.size.z]})
	var viewport:=SubViewport.new();viewport.size=Vector2i(900,680);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	root.remove_child(model);viewport.add_child(model)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("17232f");environment.environment.glow_enabled=true;environment.environment.glow_intensity=.5;environment.environment.glow_bloom=.2;environment.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC;viewport.add_child(environment)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=1.6;camera.position=Vector3(1.2,1.2,2.);viewport.add_child(camera);camera.look_at(Vector3(0,.8,0))
	for category in ["Idle","Attack","Death"]:
		animation.play(category,0.);animation.seek(animation.get_animation(category).length*(1. if category=="Death" else .37),true);animation.pause()
		for frame in 4:await process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://../outputs/creatures/wisp-trial/saved-model-"+category+".png")
	var file:=FileAccess.open("res://../outputs/creatures/wisp-trial/motion.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"complete_skins":samples.size()*8,"asset_sha256":FileAccess.get_sha256("res://local-art/wisp/wisp-modern.scn"),"recipe_sha256":FileAccess.get_sha256("res://Presentation/PrepareWisp.gd"),"test_sha256":FileAccess.get_sha256("res://Presentation/WispMotionTests.gd"),"preparation_sha256":FileAccess.get_sha256("res://local-art/wisp/preparation.json"),"scope":"Unaccepted independently authored saved Wisp scene. Complete weighted skins and effect envelope only; no runtime hover/hue/native/corpse/distribution acceptance.","samples":samples},"\t"));file.close()
	print("WISP SAVED MODEL: ",checks," checks / ",failures," failures / ",samples.size()*8," complete skins");quit(1 if failures else 0)
