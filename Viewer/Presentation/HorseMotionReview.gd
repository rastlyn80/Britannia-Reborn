extends SceneTree
## Local animal motion review; no gameplay or network position is invented.
var horses: Array=[]
var capture_path:=""
var elapsed:=0.
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1700,1000)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):capture_path=arg.substr(10)
	var stage:=Node3D.new();root.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("263843");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("c9d6df");env.environment.ambient_light_energy=.6;stage.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_energy=1.2;sun.shadow_enabled=true;stage.add_child(sun)
	var ground:=MeshInstance3D.new();var plane:=BoxMesh.new();plane.size=Vector3(30,.1,30);ground.mesh=plane;ground.position.y=-.05;var mat:=StandardMaterial3D.new();mat.albedo_color=Color("64716a");ground.material_override=mat;stage.add_child(ground)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=6.2;stage.add_child(camera);camera.position=Vector3(0,3.,7.);camera.look_at(Vector3(0,.9,0))
	for i in 4:
		var horse:=preload("res://Presentation/HorseVisual.gd").new();stage.add_child(horse);horse.position.x=(float(i)-1.5)*2.4;horse.rotation.y=-.8;horse.set_physics_process(false);horses.append(horse)
		horse.apply_identity([0xc8,0xe2,0xe4,0xcc][i],0)
		var clip: String=["idle","gallop","hit","death"][i];horse.current_clip=clip;horse.animator.play(clip);horse.animator.seek([0.,.25,.25,1.8][i],true);horse.animator.pause();horse.set_process(false)
		var label:=Label3D.new();label.text=clip;label.position.y=2.5;label.font_size=30;label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;horse.add_child(label)
	var canvas:=CanvasLayer.new();root.add_child(canvas);var title:=Label.new();title.position=Vector2(18,14);title.text="BRITANNIA REBORN / authored horse motion additions / local pose review";title.add_theme_font_size_override("font_size",20);canvas.add_child(title)
func _process(delta: float) -> bool:
	elapsed+=delta
	if capture_path!="" and elapsed>1.:
		RenderingServer.force_draw(false);var result:=root.get_texture().get_image().save_png(capture_path);print("HORSE MOTION REVIEW ",result);quit(result);capture_path=""
	return false
