extends SceneTree
## Reproducible animated before/after with the playable body's exact wardrobe.
var actors: Array=[]
var labels: Array=[]
var clip:="Walk"
var outfit:="viking"
var elapsed:=0.
var capture:=""
var compare_prepared:=false
var angle:=0.
var sex:="both"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--clip="):clip=arg.substr(7)
		if arg.begins_with("--outfit="):outfit=arg.substr(9)
		if arg.begins_with("--screenshot="):capture=arg.substr(13)
		if arg=="--compare-prepared":compare_prepared=true
		if arg.begins_with("--angle="):angle=float(arg.substr(8))
		if arg.begins_with("--sex="):sex=arg.substr(6)
	call_deferred("build")
func build() -> void:
	var stage:=Node3D.new();root.add_child(stage)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("26333e")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color("bdcbd5");environment.environment.ambient_light_energy=.45
	environment.environment.tonemap_mode=Environment.TONE_MAPPER_AGX;stage.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-48,-25,0);light.light_energy=1.05;light.shadow_enabled=true;stage.add_child(light)
	var floor_node:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=Vector3(20,.1,12);floor_node.mesh=mesh;floor_node.position.y=-.05
	var material:=StandardMaterial3D.new();material.albedo_color=Color("5b6264");floor_node.material_override=material;stage.add_child(floor_node)
	var indices: Array=[0,1] if sex=="male" else ([2,3] if sex=="female" else [0,1,2,3])
	for slot in indices.size():
		var i: int=indices[slot]
		var actor:=preload("res://Presentation/HumanVisual.gd").new()
		actor.female=i>=2;actor.use_modern_motion=compare_prepared or i%2==1
		actor.war_mode=outfit=="sword"
		actor.position.x=(slot-(indices.size()-1)*.5)*1.4;stage.add_child(actor)
		actor.rotation_degrees.y=angle
		if compare_prepared and i%2==0:
			assert(ResourceLoader.exists(actor.folder+"/motion-before-arm/human-motion.glb"),"Snapshot the previous prepared motion before rebuilding")
			actor.motion_profile=preload("res://Presentation/HumanMotion.gd").install(actor,actor.folder+"/motion-before-arm")
			actor.grip.use_prepared_clip(actor.animator.get_animation("Sword_Idle"))
			actor.animator.play("Idle")
		var worn: Array=[{"id":0x203b,"layer":11}]
		var ids: Array=[0x1fa1,0x1539,0x170b] if not outfit.begins_with("robe") else [0x1f03]
		if outfit in ["sword","carry","robe-sword"]:ids.append(0xf5e)
		if outfit=="kilt":ids=[0x1fa1,0x1537,0x170b]
		for id in ids:worn.append({"id":id})
		actor.set_equipment(worn);actors.append(actor)
		var label:=Label3D.new();label.text=("Female" if i>=2 else "Male")+(" · NEW" if i%2==1 else " · previous")
		label.font_size=32;label.pixel_size=.003;label.position=Vector3(actor.position.x,2.05,0);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;stage.add_child(label);labels.append(label)
	var camera:=Camera3D.new();camera.fov=43.;stage.add_child(camera);camera.position=Vector3(0,2.2,7.2);camera.look_at(Vector3(0,1.1,0))
	if indices.size()==2:camera.position=Vector3(0,1.9,4.6);camera.look_at(Vector3(0,1.05,0))
	var ui:=VBoxContainer.new();ui.position=Vector2(24,18);root.add_child(ui)
	var title:=Label.new();title.text="BRITANNIA REBORN · HUMAN MOTION\n"+("Previous prepared / relaxed arm motion" if compare_prepared else "Original fallback / prepared motion")+" · same bodies, materials and wardrobe";ui.add_child(title)
	var row:=HBoxContainer.new();ui.add_child(row)
	for name in ["Idle","Walk","Jog","Run","Sword_Idle","Sword_A","Punch_Jab","Sword_Block","Cast","Hit"]:
		var button:=Button.new();button.text=name.replace("_"," ");row.add_child(button)
		button.pressed.connect(func():clip=name;elapsed=0.;play_all())
	play_all()
	if not capture.is_empty():
		for actor in actors:actor.animator.seek(actor.animator.current_animation_length*.23,true);actor.animator.pause()
		for i in 15:await process_frame
		await RenderingServer.frame_post_draw
		quit(root.get_texture().get_image().save_png(capture))
func play_all() -> void:
	for actor in actors:
		var chosen: String=clip if actor.animator.has_animation(clip) else ("Walk" if clip=="Jog" else "Idle")
		if actor.use_modern_motion and (preload("res://Presentation/HumanActions.gd").locomotion(chosen) or chosen=="Idle"):chosen=actor.stance_clip(chosen)
		actor.current_clip="";actor.play(chosen,.12)
		var travel: float=float({"Walk":.98,"Jog":2.44,"Run":4.88,"Sprint":7.}.get(clip,0.))
		if travel>0:
			var pace: float=float(actor.motion_profile.clips.get(actor.animator.current_animation,{}).get("native_speed_mps",1.)) if actor.use_modern_motion else (3. if chosen=="Run" else 1.4)
			actor.animator.speed_scale=clampf(travel/maxf(.1,pace),.65 if actor.use_modern_motion else .75,1.8 if actor.use_modern_motion else 2.)
		else:actor.animator.speed_scale=1.
func _process(delta: float) -> bool:
	if actors.is_empty() or not capture.is_empty():return false
	elapsed+=delta
	if elapsed>3.5:elapsed=0.;play_all()
	return false
