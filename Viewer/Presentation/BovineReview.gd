extends SceneTree
const Registry=preload("res://Presentation/AnimalVisual.gd")
var actors: Array=[]
var capture_dir:=""
var body:=0xd8
var clip:="Walk"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--body="):body=int(arg.trim_prefix("--body="))
		if arg.begins_with("--capture-dir="):capture_dir=arg.trim_prefix("--capture-dir=")
	call_deferred("build")
func button(parent: Node,text: String,action: Callable) -> void:
	var b:=Button.new();b.text=text;b.pressed.connect(action);parent.add_child(b)
func build() -> void:
	root.size=Vector2i(1440,900);var stage:=Node3D.new();root.add_child(stage)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();var env:=environment.environment;env.background_mode=Environment.BG_COLOR;env.background_color=Color("24343f");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("d6dce4");env.ambient_light_energy=.65;env.tonemap_mode=Environment.TONE_MAPPER_AGX;stage.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.35;sun.shadow_enabled=true;stage.add_child(sun)
	var floor_mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(30,.1,30);floor_mesh.mesh=box;floor_mesh.position.y=-.05;var mat:=StandardMaterial3D.new();mat.albedo_color=Color("61726a");mat.roughness=.95;floor_mesh.material_override=mat;stage.add_child(floor_mesh)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.2;stage.add_child(camera);camera.position=Vector3(.6,2.5,8);camera.look_at(Vector3(.6,.9,0))
	for i in 3:
		var actor:=Registry.create(body);actor.treatment=["original","rounded","modern"][i];stage.add_child(actor);actor.apply_identity(body,0);actor.set_physics_process(false);actor.contact.enabled=false;actor.reins.visible=false;actor.position.x=(i-1)*2.6;actor.rotation.y=-.8;actors.append(actor)
		var label:=Label3D.new();label.text=["Original source","Rounded geometry","Modern coat + surface"][i];label.position=Vector3(actor.position.x,2.15,0);label.font_size=27;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;stage.add_child(label)
	var canvas:=CanvasLayer.new();root.add_child(canvas);var ui:=VBoxContainer.new();ui.position=Vector2(18,14);canvas.add_child(ui)
	var title:=Label.new();title.text="BRITANNIA REBORN / "+str(Registry.BODIES[body][0]).to_upper()+" / BODY 0x%X"%body;title.add_theme_font_size_override("font_size",24);ui.add_child(title)
	var note:=Label.new();note.text="Original rig and native clips / isolated art review / native hues and interactions remain server-owned";ui.add_child(note)
	var row:=HBoxContainer.new();ui.add_child(row)
	for name in ["Idle","Walk","Run","Eat","Attack","Hit","Death","Fidget"]:button(row,name,func():play(name))
	button(row,"Hue 53",func():tint(53));button(row,"Default coat",func():tint(0))
	play(clip)
	if capture_dir!="":call_deferred("captures")
func tint(hue: int) -> void:
	for actor in actors:actor.apply_identity(body,hue)
func play(name: String) -> void:
	clip=name
	for actor in actors:actor.play(name,.1)
func captures() -> void:
	DirAccess.make_dir_recursive_absolute(capture_dir)
	for name in ["Idle","Walk","Run","Eat","Attack","Hit","Death","Fidget"]:
		for angle in [["three-quarter",-.8],["side",PI/2.]]:
			for phase in [.25,.65]:
				for actor in actors:actor.rotation.y=angle[1];actor.play(name,0.);actor.animator.seek(actor.animator.get_animation(name).length*phase,true);actor.animator.pause()
				for frame in 4:await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(capture_dir.path_join("%s-%s-%02d.png"%[name.to_lower(),angle[0],int(phase*100)]))
	print("BOVINE REVIEW: 32 actual frames / ",body);quit()
