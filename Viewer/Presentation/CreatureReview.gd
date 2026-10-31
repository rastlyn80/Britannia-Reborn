extends SceneTree
const Visual=preload("res://Presentation/CreatureVisual.gd")
var family:="bruins"
var kind:=""
var actors: Array=[]
var capture_mode:=false
var output:=""
var clip:="Walk"
var capture_clips: Array[String]=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--family="):family=arg.trim_prefix("--family=")
		if arg.begins_with("--kind="):kind=arg.trim_prefix("--kind=")
		if arg=="--capture":capture_mode=true
		if arg.begins_with("--clips="):
			for name in arg.trim_prefix("--clips=").split(","):capture_clips.append(name)
	call_deferred("build")
func button(parent: Node,text: String,action: Callable) -> void:
	var b:=Button.new();b.text=text;b.pressed.connect(action);parent.add_child(b)
func build() -> void:
	var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/"+family+"/preparation.json"))
	var ready: Array=preparation.models.filter(func(row: Dictionary):return row.status=="prepared" and (kind.is_empty() or row.kind==kind))
	if ready.is_empty():push_error("No prepared source trial for "+family+" / "+kind);quit(1);return
	var record: Dictionary=ready[0];kind=record.kind
	output=ProjectSettings.globalize_path("res://../outputs/creatures/"+family+"/"+kind)
	var height:=float(record.stats.original.height_m)
	root.size=Vector2i(1440,900);var stage:=Node3D.new();root.add_child(stage)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();var env:=environment.environment;env.background_mode=Environment.BG_COLOR;env.background_color=Color("24343f");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("d6dce4");env.ambient_light_energy=.65;env.tonemap_mode=Environment.TONE_MAPPER_AGX;stage.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.35;sun.shadow_enabled=true;stage.add_child(sun)
	var floor_mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(100,.1,100);floor_mesh.mesh=box;floor_mesh.position.y=-.05;var mat:=StandardMaterial3D.new();mat.albedo_color=Color("61726a");mat.roughness=.95;floor_mesh.material_override=mat;stage.add_child(floor_mesh)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=height*5.;stage.add_child(camera);camera.position=Vector3(height*.45,height*2.,height*7.);camera.look_at(Vector3(height*.45,height*.7,0))
	for i in 3:
		var actor:=Visual.new();actor.entry=record;actor.treatment=["original","rounded","modern"][i];stage.add_child(actor);actor.set_physics_process(false);actor.contact.enabled=false;actor.position.x=(i-1)*height*2.1;actor.rotation.y=-.8;actors.append(actor)
		var baseline:="Source geometry / replacement atlas" if record.has("missing_source_atlas") else "Original source"
		var label:=Label3D.new();label.text=[baseline,"Rounded geometry","Modern surface"][i];label.position=Vector3(actor.position.x,height*1.8,0);label.font_size=27;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;stage.add_child(label)
	var canvas:=CanvasLayer.new();root.add_child(canvas);var ui:=VBoxContainer.new();ui.position=Vector2(18,14);canvas.add_child(ui)
	var title:=Label.new();title.text="BRITANNIA REBORN / "+kind.replace("_"," ").to_upper();title.add_theme_font_size_override("font_size",24);ui.add_child(title)
	var note:=Label.new();note.text="Original rig and source clips / bounded geometry / "+str(record.surface)+" / local review";ui.add_child(note)
	var row:=HFlowContainer.new();row.custom_minimum_size=Vector2(1360,0);ui.add_child(row)
	var names: Array[String]=["Idle","Walk","Run","Eat","Attack","Hit","Death","Fidget"]
	for name in actors[0].animator.get_animation_list():
		if str(name)!="RESET" and not names.has(str(name)):names.append(str(name))
	for name in names:button(row,name,func():play(name))
	button(row,"Hue 53",func():tint(53));button(row,"Default coat",func():tint(0))
	play(clip)
	if capture_mode:
		create_timer(90.).timeout.connect(func():push_error("Creature capture did not finish within 90 seconds");quit(1))
		call_deferred("captures")
func tint(hue: int) -> void:
	for actor in actors:actor.apply_identity(0,hue)
func play(name: String) -> void:
	clip=name
	for actor in actors:actor.play(name,.1)
func captures() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	var names: Array[String]=[]
	if not capture_clips.is_empty():names.assign(capture_clips)
	else:names.assign(["Idle","Walk","Run","Eat","Attack","Hit","Death","Fidget"])
	for name in names:
		if not actors[0].animator.has_animation(name):push_error("Unavailable source/replacement clip: "+name);quit(1);return
		for angle in [["three-quarter",-.8],["side",PI/2.]]:
			for actor in actors:actor.rotation.y=angle[1];actor.play(name,0.);actor.animator.seek(actor.animator.get_animation(name).length*.35,true);actor.animator.pause()
			for frame in 4:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("%s-%s.png"%[name.to_lower(),angle[0]]))
	print("CREATURE REVIEW: ",names.size()*2," actual frames / ",kind);quit()
