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
var show_coats:=false
var preview_hue:=0
var mount_cycle:=false
var cycle_stage:=0
var loose_horses: Array=[]
var capture_pending:=false
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
		if arg=="--coats":show_coats=true
		if arg=="--mount-cycle":mount_cycle=true
		if arg.begins_with("--hue="):preview_hue=int(arg.substr(6))
	var stage:=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("263843");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("c9d6df");env.environment.ambient_light_energy=.55;env.environment.tonemap_mode=Environment.TONE_MAPPER_AGX
	var sky:=Sky.new();var skymat:=ProceduralSkyMaterial.new();skymat.sky_top_color=Color("738fa8");skymat.sky_horizon_color=Color("d4dce1");skymat.ground_bottom_color=Color("444b50");skymat.ground_horizon_color=Color("8e979f");sky.sky_material=skymat;env.environment.sky=sky;env.environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY;stage.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.3;sun.shadow_enabled=true;stage.add_child(sun)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-20,145,0);fill.light_energy=.35;stage.add_child(fill)
	var ground:=MeshInstance3D.new();var plane:=BoxMesh.new();plane.size=Vector3(30,.1,30);ground.mesh=plane;ground.position.y=-.05;var mat:=StandardMaterial3D.new();mat.albedo_color=Color("64716a");ground.material_override=mat;stage.add_child(ground)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4.3;stage.add_child(camera);camera.position=Vector3(0,2.4,7);camera.look_at(Vector3(0,1.35,0))
	if show_coats:camera.size=5.6
	for i in (4 if show_coats else 2):
		var female: bool=i%2==1
		var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=401 if female else 400;stage.add_child(actor);actor.set_physics_process(false);actor.position.x=(float(i)-1.5)*2.3 if show_coats else (1.3 if female else -1.3)
		var outfit: Array=[{"id":0x1415},{"id":0x1410},{"id":0x1411},{"id":0x1412},{"id":0x1414},{"id":0x170b},{"id":0x203c if female else 0x203d,"layer":11,"hue":1147}]
		outfit.append({"id":preload("res://Presentation/HorseVisual.gd").BODIES.values()[i] if show_coats else 0x3e9f,"layer":25,"hue":preview_hue,"serial":0x40000001})
		worn.append(outfit);actor.apply_server_appearance({"body":401 if female else 400,"hue":1002},outfit.filter(func(item: Dictionary):return int(item.get("layer",0))!=25) if mount_cycle else outfit);actors.append(actor)
		loose_horses.append(null)
		if show_coats:
			var label:=Label3D.new();label.name="CoatLabel";label.text=actor.horse_visual.get_meta("coat_name","")+" / "+str(actor.horse_visual.native_body)+" / hue "+str(preview_hue);label.position.y=-.22;label.no_depth_test=true;label.font_size=24;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;actor.add_child(label)
	var canvas:=CanvasLayer.new();root.add_child(canvas);var ui:=VBoxContainer.new();ui.position=Vector2(18,14);canvas.add_child(ui)
	var title:=Label.new();title.text="BRITANNIA REBORN / HORSE AND RIDER / local animation review";title.add_theme_font_size_override("font_size",20);ui.add_child(title)
	action_label=Label.new();action_label.text="Male and female / live server identity integration / visual review uses local fixtures";ui.add_child(action_label)
	var controls:=HBoxContainer.new();ui.add_child(controls)
	for entry in [["Stand",0.],["Walk",1.8],["Travel",4.88],["Run",9.75]]:button(controls,entry[0],func():speed=float(entry[1]))
	button(controls,"Rear up",func():
		for actor in actors:
			if actor.horse_visual!=null:actor.horse_visual.rear())
	button(controls,"Horse flinch",func():
		for actor in actors:
			if actor.horse_visual!=null:actor.horse_visual.receive_action({"protocol":"new","type":4}))
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
			actors[i].apply_server_appearance({"body":actors[i].native_body,"hue":1002},outfit))
	button(clothes,"Robe / armour",func():
		for i in actors.size():
			var outfit: Array=worn[i].duplicate(true)
			if not actors[i].human_visual.server_equipment.any(func(item: Dictionary):return int(item.id)==0x1f03):outfit.append({"id":0x1f03,"hue":0})
			actors[i].apply_server_appearance({"body":actors[i].native_body,"hue":1002},outfit))
	for entry in [["Front",0.],["Side",PI/2.],["Three-quarter",-.85],["Back",PI]]:button(clothes,entry[0],func():angle=float(entry[1]))
	var colours:=HBoxContainer.new();ui.add_child(colours)
	for entry in [["Tan",0xc8],["Grey",0xe2],["Dun",0xe4],["Brown",0xcc]]:button(colours,entry[0],func():preview_colour(int(entry[1]),-1))
	for entry in [["Default colour",0],["Hue 53",53],["Hue 1153",1153],["Partial hue 53",0x8000|53]]:button(colours,entry[0],func():preview_colour(0,int(entry[1])))
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
func preview_colour(body: int,hue: int) -> void:
	for i in actors.size():
		var original: Dictionary=preload("res://Presentation/HorseVisual.gd").mount_item(worn[i])
		if body:original.id=preload("res://Presentation/HorseVisual.gd").BODIES[body]
		if hue>=0:original.hue=hue
		for j in worn[i].size():
			if int(worn[i][j].get("layer",0))==25:worn[i][j]=original.duplicate(true)
		var actual: Array=actors[i].human_visual.server_equipment.duplicate(true)
		for j in actual.size():
			if int(actual[j].get("layer",0))==25:actual[j]=original.duplicate(true)
		actors[i].apply_server_appearance({"body":actors[i].native_body,"hue":1002},actual)
		if loose_horses[i]!=null:loose_horses[i].apply_identity(preload("res://Presentation/HorseVisual.gd").horse_body(int(original.id)),int(original.get("hue",0)))
func _process(delta: float) -> bool:
	if camera==null:return false
	elapsed+=delta
	if mount_cycle:
		if (cycle_stage==0 and elapsed>.35) or (cycle_stage==1 and elapsed>3.0) or (cycle_stage==2 and elapsed>5.5):
			for i in actors.size():
				var outfit: Array=worn[i] if cycle_stage!=1 else worn[i].filter(func(item: Dictionary):return int(item.get("layer",0))!=25)
				actors[i].apply_server_appearance({"body":actors[i].native_body,"hue":1002},outfit)
			cycle_stage+=1
	for actor in actors:actor.animate(speed>0.,angle,delta,speed)
	for i in actors.size():
		var actor: Node3D=actors[i]
		if actor.retiring_horse or actor.horse_visual==null:
			if loose_horses[i]==null:
				var loose:=preload("res://Presentation/HorseVisual.gd").new();actor.get_parent().add_child(loose);loose.position=actor.position
				var item: Dictionary=preload("res://Presentation/HorseVisual.gd").mount_item(worn[i]);loose.apply_identity(preload("res://Presentation/HorseVisual.gd").horse_body(int(item.id)),int(item.get("hue",0)));loose_horses[i]=loose
			loose_horses[i].rotation.y=actor.rotation.y
		elif loose_horses[i]!=null:loose_horses[i].free();loose_horses[i]=null
		var label:=actor.get_node_or_null("CoatLabel")
		var horse: Node3D=actor.horse_visual if actor.horse_visual!=null else loose_horses[i]
		if label!=null and horse!=null:label.text=horse.get_meta("coat_name","")+" / "+str(horse.native_body)+" / hue "+str(horse.native_hue)
	if not capture_pending and sequence_path!="" and elapsed>=next_frame:
		capture_pending=true;next_frame=elapsed+.05;call_deferred("save_frame",true)
	if not capture_pending and capture_path!="" and elapsed>1.5:
		capture_pending=true;call_deferred("save_frame",false)
	return false
func save_frame(sequence: bool) -> void:
	# Wait for the normal scene/skin update. A forced draw inside _process can
	# capture newly rebuilt skins before their first render buffers are ready.
	await RenderingServer.frame_post_draw
	var path:=sequence_path.path_join("frame-%03d.png"%sequence_frame) if sequence else capture_path
	var result:=root.get_texture().get_image().save_png(path)
	if result!=OK:quit(result);return
	capture_pending=false
	if sequence:
		sequence_frame+=1
		if sequence_frame>=(100 if mount_cycle else 48):capture_pending=true;sequence_path="";print("HORSE SEQUENCE ",sequence_frame," frames");quit()
	else:print("HORSE REVIEW ",path," ",result);quit()
