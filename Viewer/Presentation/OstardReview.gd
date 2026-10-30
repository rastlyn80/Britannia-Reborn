extends SceneTree
## Three treatments of the same source creature in normal Godot render frames.
const Visual=preload("res://Presentation/OstardVisual.gd")
var stage: Node3D
var camera: Camera3D
var actors: Array=[]
var labels: Array=[]
var selected_clip:="Walk"
var angle:=-.6
var clips_paused:=false
var head_view:=false
var capture_dir:=""
var sequence_dir:=""
var material_test_path:=""
var pose_slider: HSlider
var pose_caption: Label
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):capture_dir=arg.trim_prefix("--capture-dir=")
		if arg.begins_with("--sequence-dir="):sequence_dir=arg.trim_prefix("--sequence-dir=")
		if arg.begins_with("--material-test="):material_test_path=arg.trim_prefix("--material-test=")
	call_deferred("build")
func build() -> void:
	root.size=Vector2i(1440,950)
	stage=Node3D.new();root.add_child(stage)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();var env:=environment.environment
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("25333d");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("cbd4dd");env.ambient_light_energy=.55;env.tonemap_mode=Environment.TONE_MAPPER_AGX
	var sky:=Sky.new();var sky_mat:=ProceduralSkyMaterial.new();sky_mat.sky_top_color=Color("7b96ae");sky_mat.sky_horizon_color=Color("d5dde0");sky.sky_material=sky_mat;env.sky=sky;env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY;stage.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.25;sun.shadow_enabled=true;stage.add_child(sun)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-25,145,0);fill.light_energy=.35;stage.add_child(fill)
	var floor_mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(30,.1,30);floor_mesh.mesh=box;floor_mesh.position.y=-.05;var floor_mat:=StandardMaterial3D.new();floor_mat.albedo_color=Color("596660");floor_mat.roughness=.95;floor_mesh.material_override=floor_mat;stage.add_child(floor_mesh)
	for treatment in ["original","rounded","modern"]:
		var actor:=Visual.new();actor.treatment=treatment;stage.add_child(actor);actors.append(actor)
		var label:=Label3D.new();label.font_size=28;label.pixel_size=.0026;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=true
		label.text={"original":"ORIGINAL\n185 triangles / 128 px","rounded":"REFINED GEOMETRY\n2,960 triangles / original atlas","modern":"REFINED + NEW MATERIAL\n2,960 triangles / 1,254 px"}[treatment];stage.add_child(label);labels.append(label)
		if treatment=="modern":
			var mesh: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0]
			var material: StandardMaterial3D=mesh.mesh.surface_get_material(0)
			label.text="REFINED + NEW MATERIAL\n2,960 triangles / %d px"%material.albedo_texture.get_width()
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;stage.add_child(camera)
	var canvas:=CanvasLayer.new();root.add_child(canvas);var ui:=VBoxContainer.new();ui.position=Vector2(18,14);canvas.add_child(ui)
	var title:=Label.new();title.text="BRITANNIA REBORN / THIRD DAWN DESERT OSTARD / PRIVATE COMPARISON";title.add_theme_font_size_override("font_size",21);ui.add_child(title)
	var note:=Label.new();note.text="Left: source / centre: geometry only / right: geometry + generated atlas + surface detail\nSame 24-bone rig and seven source clips / local visual trial / no live creature replacement";ui.add_child(note)
	var actions:=HBoxContainer.new();ui.add_child(actions)
	for clip in Visual.CLIPS:button(actions,clip,func():choose_clip(clip))
	button(actions,"Pause / resume",func():
		clips_paused=not clips_paused
		for actor in actors:
			if clips_paused:actor.animator.pause()
			else:actor.animator.play())
	var views:=HBoxContainer.new();ui.add_child(views)
	button(views,"Full body",func():head_view=false;layout())
	button(views,"Head comparison",func():head_view=true;layout())
	for view in [["Front",0.],["Three-quarter",-.6],["Side",PI/2.],["Back",PI]]:button(views,view[0],func():angle=view[1];layout())
	for hue in [["Natural",0],["Hue 53",53],["Partial hue 53",0x8000|53]]:button(views,hue[0],func():actors[2].set_hue(int(hue[1])))
	var pose:=HBoxContainer.new();ui.add_child(pose);pose_caption=Label.new();pose_caption.text="Cycle position ";pose.add_child(pose_caption)
	pose_slider=HSlider.new();pose_slider.min_value=0.;pose_slider.max_value=.999;pose_slider.step=.001;pose_slider.custom_minimum_size=Vector2(300,0);pose.add_child(pose_slider);pose_slider.value_changed.connect(func(value: float):set_pose(selected_clip,value))
	layout();choose_clip("Walk")
	if material_test_path!="":call_deferred("test_material")
	elif capture_dir!="":call_deferred("capture_matrix")
	elif sequence_dir!="":call_deferred("capture_sequence")
func button(parent: Node,text: String,action: Callable) -> void:
	var control:=Button.new();control.text=text;control.pressed.connect(action);parent.add_child(control)
func layout() -> void:
	for i in actors.size():
		actors[i].position.x=(float(i)-1.)*2.
		actors[i].rotation.y=angle;actors[i].visible=not head_view or i!=1;labels[i].visible=not head_view
		labels[i].position=Vector3(actors[i].position.x,-.18,.3)
	camera.size=1.65 if head_view else 4.2
	var target:=Vector3(0,1.05,0)
	if head_view:
		var average:=Vector3.ZERO
		for i in [0,2]:
			var actor: Node3D=actors[i]
			var rig: Skeleton3D=actor.skeleton
			var head:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 head")).origin)
			actor.position.x+=(-.6 if i==0 else .6)-head.x
			head.x=(-.6 if i==0 else .6);average+=head*.5
		target=average+Vector3(0,.06,0)
	camera.position=target+Vector3(0,.15,8.);camera.look_at(target)
func _process(_delta: float) -> bool:
	if head_view and camera!=null:layout()
	return false
func choose_clip(clip: String) -> void:
	selected_clip=clip;clips_paused=false
	pose_caption.text=clip+" / playing "
	for actor in actors:actor.play(clip)
func set_pose(clip: String,phase: float) -> void:
	selected_clip=clip;clips_paused=true
	pose_caption.text="%s / %02d%% "%[clip,int(phase*100.)];pose_slider.set_value_no_signal(phase)
	for actor in actors:
		actor.animator.play(clip,0.);actor.animator.seek(actor.animator.get_animation(clip).length*phase,true);actor.animator.pause()
	if head_view:layout()
func capture_frame(path: String) -> void:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	var result:=root.get_texture().get_image().save_png(path)
	if result!=OK:push_error("Ostard capture failed: "+path);quit(1)
func capture_matrix() -> void:
	var rows: Array=[]
	for clip in Visual.CLIPS:
		for view in [["three-quarter",-.6],["side",PI/2.]]:
			for phase in [.2,.65]:
				head_view=false;angle=float(view[1]);layout();set_pose(clip,phase)
				var name:="%s-%s-%02d.png"%[clip.to_lower(),view[0],int(phase*100.)]
				await capture_frame(capture_dir.path_join(name));rows.append({"file":name,"clip":clip,"angle":view[0],"phase":phase})
	for view in [["front",0.],["three-quarter",-.6],["side",PI/2.]]:
		head_view=true;angle=float(view[1]);layout();set_pose("Idle",.2)
		var name:="head-"+str(view[0])+".png";await capture_frame(capture_dir.path_join(name));rows.append({"file":name,"clip":"Idle","angle":view[0],"head":true})
	var file:=FileAccess.open(capture_dir.path_join("captures.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"frames":rows,"renderer":RenderingServer.get_current_rendering_method(),"scope":"31 actual render frames; local original/refined/material trial, not live world or generated creature screenshots."},"\t"));file.close()
	print("OSTARD CAPTURES: ",rows.size());quit()
func capture_sequence() -> void:
	head_view=false;angle=-.6;layout()
	var timings: Dictionary={}
	for clip in ["Walk","Run"]:
		timings[clip.to_lower()]={"cycle_seconds":actors[0].animator.get_animation(clip).length,"samples_per_cycle":24,"cycles":2}
		for frame in 48:
			set_pose(clip,float(frame%24)/24.);await capture_frame(sequence_dir.path_join("%s-%02d.png"%[clip.to_lower(),frame]))
	var file:=FileAccess.open(sequence_dir.path_join("timings.json"),FileAccess.WRITE);file.store_string(JSON.stringify(timings,"\t"));file.close()
	print("OSTARD SEQUENCE: 96 completed render frames");quit()
func snapshot() -> Image:
	for frame in 5:await process_frame
	await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image();picture.resize(360,238,Image.INTERPOLATE_BILINEAR);return picture
func difference(a: Image,b: Image) -> float:
	var total:=0.
	for y in a.get_height():
		for x in a.get_width():
			var p:=a.get_pixel(x,y);var q:=b.get_pixel(x,y)
			total+=absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b)
	return total/(float(a.get_width()*a.get_height())*3.)
func test_material() -> void:
	head_view=false;layout();set_pose("Idle",.2)
	for i in actors.size():actors[i].visible=i==2;labels[i].visible=false
	actors[2].position=Vector3.ZERO
	var mesh: MeshInstance3D=actors[2].model.find_children("*","MeshInstance3D",true,false)[0]
	var mat: ShaderMaterial=mesh.get_surface_override_material(0)
	mat.set_shader_parameter("detail_strength",0.);var flat:=await snapshot()
	mat.set_shader_parameter("detail_strength",.32);var detail:=await snapshot()
	mat.set_shader_parameter("skin_roughness",.4);var smooth_skin:=await snapshot()
	mat.set_shader_parameter("skin_roughness",.88);var rough_skin:=await snapshot()
	mat.set_shader_parameter("skin_roughness",.78)
	var sun: DirectionalLight3D=stage.find_children("*","DirectionalLight3D",true,false)[0]
	sun.rotation_degrees=Vector3(-22,-80,0);var sidelight:=await snapshot()
	actors[2].set_hue(53);var dyed:=await snapshot()
	var metrics:={"normal_response":difference(flat,detail),"roughness_response":difference(smooth_skin,rough_skin),"light_response":difference(detail,sidelight),"hue_response":difference(sidelight,dyed),"renderer":RenderingServer.get_current_rendering_method(),"scope":"Actual GPU frames, same pose/geometry, isolated shader parameters and light; offline visual trial."}
	var failures: Array=[]
	for key in ["normal_response","roughness_response","light_response","hue_response"]:
		if metrics[key]<=.000005:failures.append(key+" had no visible GPU response")
	metrics["failures"]=failures
	var file:=FileAccess.open(material_test_path,FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"\t"));file.close()
	print("OSTARD GPU: ",metrics);quit(1 if failures else 0)
