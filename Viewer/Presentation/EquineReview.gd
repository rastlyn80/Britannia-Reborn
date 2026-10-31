extends SceneTree
## Real rendered gallery: loose animal plus both riders. No server fixture claim.
const Horse=preload("res://Presentation/HorseVisual.gd")
const Registry=preload("res://Presentation/EquineRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
var stage: Node3D
var camera: Camera3D
var actors: Array=[]
var title: Label
var entries: Array=[]
var selected:=0
var speed:=1.8
var angle:=-.7
var capture_dir:=""
var elapsed:=0.
var rendering:=false
var records: Array=[]
var capture_view:=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1440,950)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):capture_dir=arg.trim_prefix("--capture-dir=")
	for body: int in Registry.BODIES:entries.append({"body":body,"item":int(Registry.BODIES[body][2]),"name":str(Registry.BODIES[body][0])})
	for body: int in Registry.COMPATIBILITY:entries.append({"body":body,"item":0,"name":str(Registry.COMPATIBILITY[body][0])})
	for item: int in Registry.ETHEREALS:entries.append({"body":int(Registry.ETHEREALS[item][0]),"item":item,"name":str(Registry.ETHEREALS[item][1])})
	stage=Node3D.new();root.add_child(stage)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();var env:=environment.environment
	env.background_mode=Environment.BG_COLOR;env.background_color=Color("24313b");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("cbd8df");env.ambient_light_energy=.6;env.tonemap_mode=Environment.TONE_MAPPER_AGX
	var sky:=Sky.new();sky.sky_material=ProceduralSkyMaterial.new();env.sky=sky;env.reflected_light_source=Environment.REFLECTION_SOURCE_SKY;stage.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-35,0);sun.light_energy=1.3;sun.shadow_enabled=true;stage.add_child(sun)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-25,150,0);fill.light_energy=.4;stage.add_child(fill)
	var ground:=MeshInstance3D.new();var plane:=BoxMesh.new();plane.size=Vector3(50,.1,40);ground.mesh=plane;ground.position.y=-.05;var mat:=StandardMaterial3D.new();mat.albedo_color=Color("596560");mat.roughness=.92;ground.material_override=mat;stage.add_child(ground)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.1;stage.add_child(camera);camera.position=Vector3(0,3.1,9);camera.look_at(Vector3(0,1.4,0))
	var canvas:=CanvasLayer.new();root.add_child(canvas);var ui:=VBoxContainer.new();ui.position=Vector2(20,15);canvas.add_child(ui)
	title=Label.new();title.add_theme_font_size_override("font_size",23);ui.add_child(title)
	var note:=Label.new();note.text="BRITANNIA REBORN / shared animated horse rig / original fittings / native identity + hue / local visual fixtures";ui.add_child(note)
	var choices:=HBoxContainer.new();ui.add_child(choices)
	button(choices,"Previous",func():select((selected+entries.size()-1)%entries.size()))
	button(choices,"Next",func():select((selected+1)%entries.size()))
	for pair in [["Stand",0.],["Walk",1.8],["Run",9.75]]:button(choices,pair[0],func():speed=pair[1])
	button(choices,"Side",func():angle=PI/2.)
	button(choices,"Three quarter",func():angle=-.7)
	button(choices,"Hue 53",func():tint(53))
	button(choices,"Native/default hue",func():tint(0x4001 if Registry.ETHEREALS.has(int(entries[selected].item)) else 0))
	select(0)
func button(parent: Node,text: String,action: Callable) -> void:
	var control:=Button.new();control.text=text;control.pressed.connect(action);parent.add_child(control)
func select(index: int) -> void:
	selected=index
	for actor in actors:actor.free()
	actors.clear()
	for child in stage.get_children():
		if child is Label3D:child.free()
	var entry: Dictionary=entries[index]
	var ethereal: bool=Registry.ETHEREALS.has(int(entry.item))
	title.text=("%s  |  mount 0x%X / rig proxy 0x%X"%[entry.name,int(entry.item),int(entry.body)]) if ethereal else ("%s  |  body 0x%X / mount 0x%X"%[entry.name,int(entry.body),int(entry.item)])
	for slot in (2 if ethereal else 3 if int(entry.item)!=0 else 1):
		var rider: bool=ethereal or slot!=1 and int(entry.item)!=0
		var female: bool=slot==1 if ethereal else slot==2
		var actor:=Avatar.new();actor.initial_body=(401 if female else 400) if rider else int(entry.body);stage.add_child(actor);actor.set_physics_process(false)
		actor.position.x=(float(slot)-.5)*3.3 if ethereal else (float(slot)-1.)*2.7 if int(entry.item)!=0 else 0.
		var clothes: Array=[{"id":0x1f03,"hue":1153},{"id":0x1539},{"id":0x170b},{"id":0x203c if female else 0x203d,"layer":11,"hue":1147}] if female else [{"id":0x1415},{"id":0x1410},{"id":0x1411},{"id":0x1414},{"id":0x170b}]
		if rider:clothes.append({"id":int(entry.item),"layer":25,"hue":0x4001 if ethereal else 0});actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},clothes);actor.rider_contact.begin_mount(false)
		else:actor.apply_server_appearance({"body":int(entry.body),"hue":0},[])
		actors.append(actor)
		var label:=Label3D.new();label.text=("Female / robe" if female else "Male / plate") if rider else "Compatibility preview / no invented mount item" if Registry.COMPATIBILITY.has(int(entry.body)) else "Loose animal / unrideable" if int(entry.item)==0 else "Loose animal";label.position.y=-.22;label.font_size=25;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;stage.add_child(label);label.position.x=actor.position.x
	elapsed=0.
func tint(hue: int) -> void:
	for actor in actors:actor.horse_visual.apply_identity(int(entries[selected].body),hue,int(entries[selected].item) if actor.human_visual!=null else 0)
func _process(delta: float) -> bool:
	if camera==null:return false
	for actor in actors:actor.animate(speed>0.,angle,delta,speed)
	elapsed+=delta
	if capture_dir!="" and elapsed>.8 and not rendering:rendering=true;call_deferred("capture")
	return false
func capture() -> void:
	await RenderingServer.frame_post_draw
	var picture:=root.get_texture().get_image()
	var name:="%02d-%s.png"%[selected,"walk" if capture_view==0 else "run-side"]
	var path:=capture_dir.path_join(name);var error:=picture.save_png(path)
	if error!=OK:push_error("Unable to save equine capture");quit(1);return
	records.append({"file":name,"entry":entries[selected],"mode":"walk" if capture_view==0 else "run-side","size":[picture.get_width(),picture.get_height()]})
	if capture_view==0:capture_view=1;speed=9.75;angle=PI/2.;elapsed=0.
	else:
		capture_view=0;speed=1.8;angle=-.7
		if selected+1<entries.size():select(selected+1)
		else:
			var file:=FileAccess.open(capture_dir.path_join("captures.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"frames":records,"scope":"Real Forward+ frames of local visual fixtures, not multiplayer screenshots. Ethereal mounts have no fabricated loose mobile."},"\t"));file.close();print("EQUINE CAPTURES: ",records.size());quit();return
	rendering=false
