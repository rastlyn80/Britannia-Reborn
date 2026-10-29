extends SceneTree
## Local visual review only. Live mounting is exercised separately.
var actors: Array=[]
var worn: Array=[]
var speed:=0.
var angle:=-.85
var elapsed:=0.
var capture_path:=""
var sequence_path:=""
var sequence_frame:=0
var next_frame:=1.
var camera: Camera3D
var action_label: Label
func _initialize() -> void:call_deferred("run")
func button(box: HBoxContainer,label: String,action: Callable) -> void:
	var b:=Button.new();b.text=label;b.pressed.connect(action);box.add_child(b)
func run() -> void:
	root.size=Vector2i(1700,1000)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):capture_path=arg.substr(10)
		if arg.begins_with("--sequence="):sequence_path=arg.substr(11)
	var stage:=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("263843");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("c9d6df");env.environment.ambient_light_energy=.55;env.environment.tonemap_mode=Environment.TONE_MAPPER_AGX
	var sky:=Sky.new();var skymat:=ProceduralSkyMaterial.new();skymat.sky_top_color=Color("738fa8");skymat.sky_horizon_color=Color("d4dce1");skymat.ground_bottom_color=Color("444b50");skymat.ground_horizon_color=Color("8e979f");sky.sky_material=skymat;env.environment.sky=sky;env.environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY;stage.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.3;sun.shadow_enabled=true;stage.add_child(sun)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-20,145,0);fill.light_energy=.35;stage.add_child(fill)
	var ground:=MeshInstance3D.new();var plane:=BoxMesh.new();plane.size=Vector3(30,.1,30);ground.mesh=plane;ground.position.y=-.05;var mat:=StandardMaterial3D.new();mat.albedo_color=Color("64716a");ground.material_override=mat;stage.add_child(ground)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.7;stage.add_child(camera);camera.position=Vector3(0,2.4,7);camera.look_at(Vector3(0,1.35,0))
	for female in [false,true]:
		var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=401 if female else 400;stage.add_child(actor);actor.set_physics_process(false);actor.position.x=1.3 if female else -1.3
		var outfit: Array=[{"id":0x1415},{"id":0x1410},{"id":0x1411},{"id":0x1412},{"id":0x1414},{"id":0x170b},{"id":0x203c if female else 0x203d,"layer":11,"hue":1147}]
		outfit.append({"id":0x3e9f,"layer":25,"hue":0,"serial":0x40000001})
		worn.append(outfit);actor.apply_server_appearance({"body":401 if female else 400,"hue":1002},outfit);actors.append(actor)
	var canvas:=CanvasLayer.new();root.add_child(canvas);var ui:=VBoxContainer.new();ui.position=Vector2(18,14);canvas.add_child(ui)
	var title:=Label.new();title.text="BRITANNIA REBORN / HORSE AND RIDER / local animation review";title.add_theme_font_size_override("font_size",20);ui.add_child(title)
	action_label=Label.new();action_label.text="Male and female / live server identity integration / visual review uses local fixtures";ui.add_child(action_label)
	var controls:=HBoxContainer.new();ui.add_child(controls)
	for entry in [["Stand",0.],["Walk",1.8],["Travel",4.88],["Run",9.75]]:button(controls,entry[0],func():speed=float(entry[1]))
	button(controls,"Rear up",func():
		for actor in actors:
			if actor.horse_visual!=null:actor.horse_visual.rear())
	for entry in [["Attack",26],["Bow",27],["Crossbow",28],["Pat horse",29]]:button(controls,entry[0],func():
		for actor in actors:
			var outfit: Array=actor.human_visual.server_equipment.duplicate(true)
			outfit=outfit.filter(func(item: Dictionary):return int(item.get("layer",0)) not in [1,2])
			var weapon: int={26:0x13b9,27:0x13b2,28:0x0f50}.get(int(entry[1]),0)
			if weapon:outfit.append({"id":weapon,"layer":1})
			actor.apply_server_appearance({"body":actor.native_body,"hue":1002},outfit)
			actor.receive_native_action({"body":actor.native_body,"protocol":"classic","action":int(entry[1])}))
	var clothes:=HBoxContainer.new();ui.add_child(clothes)
	button(clothes,"Mount / dismount",func():
		for i in actors.size():
			var outfit: Array=worn[i].duplicate(true)
			if actors[i].horse_visual!=null:outfit=outfit.filter(func(item: Dictionary):return int(item.get("layer",0))!=25)
			actors[i].apply_server_appearance({"body":401 if i else 400,"hue":1002},outfit))
	button(clothes,"Robe / armour",func():
		for i in actors.size():
			var outfit: Array=worn[i].duplicate(true)
			if not actors[i].human_visual.server_equipment.any(func(item: Dictionary):return int(item.id)==0x1f03):outfit.append({"id":0x1f03,"hue":0})
			actors[i].apply_server_appearance({"body":401 if i else 400,"hue":1002},outfit))
	for entry in [["Front",0.],["Side",PI/2.],["Three-quarter",-.85],["Back",PI]]:button(clothes,entry[0],func():angle=float(entry[1]))
	for arg in OS.get_cmdline_user_args():
		if arg=="--walk":speed=1.8
		if arg=="--run":speed=9.75
		if arg=="--robe":
			for i in actors.size():
				var outfit: Array=worn[i].duplicate(true);outfit.append({"id":0x1f03,"hue":0})
				actors[i].apply_server_appearance({"body":401 if i else 400,"hue":1002},outfit)
		if arg=="--rear":
			for actor in actors:actor.horse_visual.rear()
			camera.size=5.;camera.position=Vector3(0,3.,7.);camera.look_at(Vector3(0,2.,0))
func _process(delta: float) -> bool:
	if camera==null:return false
	elapsed+=delta
	for actor in actors:actor.animate(speed>0.,angle,delta,speed)
	if sequence_path!="" and elapsed>=next_frame:
		RenderingServer.force_draw(false)
		var result:=root.get_texture().get_image().save_png(sequence_path.path_join("frame-%03d.png"%sequence_frame))
		if result!=OK:quit(result);return false
		sequence_frame+=1;next_frame=elapsed+.05
		if sequence_frame>=48:print("HORSE SEQUENCE 48 frames");quit();return false
	if capture_path!="" and elapsed>1.5:
		RenderingServer.force_draw(false)
		var result:=root.get_texture().get_image().save_png(capture_path)
		for actor in actors:print("HORSE CONTACT ",actor.native_body," seat ",actor.rider_contact.seat_error," stirrups ",actor.rider_contact.stirrup_errors)
		print("HORSE REVIEW ",capture_path," ",result);quit(result);capture_path=""
	return false
