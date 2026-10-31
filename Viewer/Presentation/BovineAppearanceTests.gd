extends SceneTree
const Registry=preload("res://Presentation/AnimalVisual.gd")
var viewport: SubViewport
var checks:=0
var failures:=0
var rows: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func capture() -> Image:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	var result:=viewport.get_texture().get_image();result.convert(Image.FORMAT_RGBA8);return result
func run() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(480,420);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();var env:=environment.environment;env.background_mode=Environment.BG_COLOR;env.background_color=Color.BLACK;env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.8;viewport.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-35,0);sun.light_energy=1.2;viewport.add_child(sun)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.4;camera.position=Vector3(0,1.7,6);viewport.add_child(camera);camera.look_at(Vector3(0,.9,0))
	for body: int in Registry.BODIES:
		var actor:=Registry.create(body);viewport.add_child(actor);actor.set_process(false);actor.set_physics_process(false);actor.contact.enabled=false;actor.reins.visible=false
		for clip in ["Walk","Run","Eat"]:
			for angle in [-.8,PI/2.]:
				actor.rotation.y=angle;actor.apply_identity(body,0);actor.play(clip,0.);actor.animator.seek(actor.animator.current_animation_length*.35,true);actor.animator.pause()
				var base:=await capture();actor.apply_identity(body,53);var dyed:=await capture();var occupied:=0;var changed:=0
				for y in range(0,420,2):
					for x in range(0,480,2):
						var a:=base.get_pixel(x,y);var b:=dyed.get_pixel(x,y)
						if maxf(a.r,maxf(a.g,a.b))<.04:continue
						occupied+=1
						if Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()>.025:changed+=1
				check(occupied>300,"Actual animal surface is visible in the GPU image")
				check(float(changed)/maxi(1,occupied)>.4,"Full native hue visibly recolours the actual source skin")
				rows.append({"body":body,"clip":clip,"angle":angle,"occupied_pixels":occupied,"dyed_fraction":float(changed)/maxi(1,occupied)})
		actor.free()
	var file:=FileAccess.open("res://../outputs/bovines/appearance.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"samples":rows,"scope":"Actual GPU visibility and native dye response across all four bovine bodies, three source gaits/actions and two angles. UV/anatomy review is separate."},"\t"));file.close()
	print("BOVINE GPU: ",checks-failures," / ",checks);quit(1 if failures else 0)
