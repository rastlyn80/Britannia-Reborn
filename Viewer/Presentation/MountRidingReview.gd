extends SceneTree
var actors: Array=[]
var outfits: Array=[]
var camera: Camera3D
var speed:=1.8
var angle:=-.85
var item:=0x3ea3
var capture_dir:=""
var capturing:=false
var show_pack:=false
var title: Label
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--pack":show_pack=true
		if arg.begins_with("--item="):item=int(arg.trim_prefix("--item="))
		if arg.begins_with("--capture-dir="):capture_dir=arg.trim_prefix("--capture-dir=")
	call_deferred("build")
func button(parent: Node,text: String,action: Callable) -> void:
	var control:=Button.new();control.text=text;control.pressed.connect(action);parent.add_child(control)
func build() -> void:
	root.size=Vector2i(1440,950)
	var stage:=Node3D.new();root.add_child(stage)
	var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color("25333d");world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color("cbd4dd");world.environment.ambient_light_energy=.65;world.environment.tonemap_mode=Environment.TONE_MAPPER_AGX;stage.add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.4;sun.shadow_enabled=true;stage.add_child(sun)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-25,145,0);fill.light_energy=.45;stage.add_child(fill)
	var floor_mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(30,.1,30);floor_mesh.mesh=box;floor_mesh.position.y=-.05;var material:=StandardMaterial3D.new();material.albedo_color=Color("596660");material.roughness=.95;floor_mesh.material_override=material;stage.add_child(floor_mesh)
	for sex in 2:
		var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=400+sex;stage.add_child(actor);actor.set_physics_process(false);actor.position.x=-1.35 if sex==0 else 1.35;actors.append(actor)
		outfits.append([{"id":0x1f03},{"id":0x1539},{"id":0x170b}] if sex==0 else [{"id":0x1415},{"id":0x1410},{"id":0x1411},{"id":0x1412},{"id":0x1414},{"id":0x170b}])
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.8;stage.add_child(camera);camera.position=Vector3(0,2.7,8);camera.look_at(Vector3(0,1.5,0))
	var canvas:=CanvasLayer.new();root.add_child(canvas);var ui:=VBoxContainer.new();ui.position=Vector2(18,14);canvas.add_child(ui)
	title=Label.new();title.add_theme_font_size_override("font_size",22);ui.add_child(title)
	var note:=Label.new();note.text="Male robe / female plate / actual animated rigs / local review; live permissions remain server-owned";ui.add_child(note)
	var forms:=HBoxContainer.new();ui.add_child(forms)
	for entry in [["Desert",0x3ea3],["Forest",0x3ea5],["Frenzied",0x3ea4],["Ethereal ostard",0x3eac],["Ki-rin",0x3ead],["Llama",0x3ea6],["Ethereal llama",0x3eab],["Skeletal",0x3ebb]]:button(forms,entry[0],func():item=int(entry[1]);apply())
	var controls:=HBoxContainer.new();ui.add_child(controls)
	for entry in [["Idle",0.],["Walk",1.8],["Run",6.8]]:button(controls,entry[0],func():speed=float(entry[1]))
	for entry in [["Front",0.],["Three-quarter",-.85],["Side",PI/2.],["Back",PI]]:button(controls,entry[0],func():angle=float(entry[1]))
	apply()
	if show_pack:call_deferred("pack_capture",stage)
	elif capture_dir!="":call_deferred("captures")
func pack_capture(stage: Node3D) -> void:
	capturing=true
	for actor in actors:actor.visible=false
	var pack:=preload("res://Presentation/MountVisual.gd").create(0x124);stage.add_child(pack);pack.apply_identity(0x124,0);pack.reins.visible=false
	title.text="BRITANNIA REBORN / PACK LLAMA / UNRIDEABLE SERVER ANIMAL"
	pack.rotation.y=-.85;camera.size=3.;camera.position=Vector3(0,1.8,5.);camera.look_at(Vector3(0,1.,0))
	if capture_dir.is_empty():capture_dir=ProjectSettings.globalize_path("res://../outputs/mount-integration/pack-llama")
	DirAccess.make_dir_recursive_absolute(capture_dir)
	for frame in 8:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join("stand.png"));print("PACK LLAMA CAPTURE");quit()
func apply() -> void:
	for i in actors.size():
		var worn: Array=outfits[i].duplicate(true);worn.append({"id":item,"layer":25,"hue":0x4001 if item in [0x3eac,0x3eab] else 0})
		actors[i].apply_server_appearance({"body":400+i,"hue":1002},worn);actors[i].rider_contact.begin_mount(false)
	title.text="BRITANNIA REBORN / "+("SKELETAL MOUNT" if item==0x3ebb else str(actors[0].horse_visual.kind).to_upper())+" / RIDING AND CLOTHING"
func _process(delta: float) -> bool:
	if capturing:return false
	for actor in actors:actor.animate(speed>0.,angle,delta,speed)
	return false
func captures() -> void:
	capturing=true;DirAccess.make_dir_recursive_absolute(capture_dir)
	for pair in [["Idle","Rider_Idle"],["Walk","Rider_Walk"],["Run","Rider_Run"]]:
		for view in [["three-quarter",-.85],["side",PI/2.]]:
			for phase in [.2,.65]:
				for actor in actors:
					actor.rotation.y=float(view[1]);actor.human_visual.cancel_action();actor.human_visual.set_process(false);actor.human_visual.play(pair[1],0.);actor.animator.seek(actor.animator.current_animation_length*phase,true);actor.animator.pause()
					actor.horse_visual.animator.play({"Idle":"idle","Walk":"walk","Run":"gallop"}[pair[0]] if item==0x3ebb else pair[0],0.);actor.horse_visual.animator.seek(actor.horse_visual.animator.current_animation_length*phase,true);actor.horse_visual.animator.pause()
				for frame in 5:await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(capture_dir.path_join("%s-%s-%02d.png"%[pair[0].to_lower(),view[0],int(phase*100.)]))
	print("MOUNT RIDING CAPTURES: 12 / item ",item);quit()
