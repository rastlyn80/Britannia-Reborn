extends SceneTree
## Actual rendered legacy coats/dyes and ethereal ki-rin transmission.
const Registry=preload("res://Presentation/EquineRegistry.gd")
const Mounts=preload("res://Presentation/MountVisual.gd")
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
func difference(a: Color,b: Color) -> float:return Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()
func run() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(480,420);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();var env:=environment.environment;env.background_mode=Environment.BG_COLOR;env.background_color=Color.BLACK;env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.7;viewport.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-35,0);sun.light_energy=1.2;viewport.add_child(sun)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.4;camera.position=Vector3(0,1.7,6.);viewport.add_child(camera);camera.look_at(Vector3(0,1.2,0))
	for body: int in Registry.COMPATIBILITY:
		var actor:=Mounts.create(body);viewport.add_child(actor);actor.set_process(false);actor.set_physics_process(false);actor.contact.enabled=false
		for angle in [-.8,PI/2.]:
			actor.rotation.y=angle;actor.apply_identity(body,0);actor.animator.play("walk",0.);actor.animator.seek(.25,true);actor.animator.pause()
			var original:=await capture();actor.apply_identity(body,53);var dyed:=await capture();var occupied:=0;var changed:=0
			for y in range(0,420,2):
				for x in range(0,480,2):
					var a:=original.get_pixel(x,y)
					if maxf(a.r,maxf(a.g,a.b))>.04:
						occupied+=1
						if difference(a,dyed.get_pixel(x,y))>.025:changed+=1
			check(occupied>200,"Compatibility artwork is actually visible")
			check(changed>100,"Raw server dye visibly changes the legacy category")
			rows.append({"body":body,"angle":angle,"occupied":occupied,"changed_by_hue":changed})
		actor.free()
	var opaque:=Mounts.create(0x84,0x3ead);viewport.add_child(opaque);opaque.apply_identity(0x84,0,0x3ead)
	var spectral:=Mounts.create(0x84,0x3e9c);viewport.add_child(spectral);spectral.apply_identity(0x84,0x4001,0x3e9c)
	for actor in [opaque,spectral]:actor.set_process(false);actor.set_physics_process(false);actor.contact.enabled=false;actor.animator.play("Walk",0.);actor.animator.seek(.25,true);actor.animator.pause()
	for angle in [-.8,PI/2.]:
		opaque.rotation.y=angle;spectral.rotation.y=angle
		opaque.visible=true;spectral.visible=false;env.background_color=Color.BLACK;var ordinary_black:=await capture()
		env.background_color=Color("a02954");var ordinary_pink:=await capture()
		opaque.visible=false;spectral.visible=true;var spectral_pink:=await capture();env.background_color=Color.BLACK;var spectral_black:=await capture()
		var occupied:=0;var transmitted:=0;var opaque_leaks:=0
		for y in range(0,420,2):
			for x in range(0,480,2):
				var a:=ordinary_black.get_pixel(x,y)
				if maxf(a.r,maxf(a.g,a.b))<.08:continue
				occupied+=1
				if difference(spectral_black.get_pixel(x,y),spectral_pink.get_pixel(x,y))>.03:transmitted+=1
				if difference(a,ordinary_pink.get_pixel(x,y))>.03:opaque_leaks+=1
		check(occupied>200 and float(transmitted)/occupied>.65,"Ethereal ki-rin transmits background through the actual shader")
		check(float(opaque_leaks)/maxi(1,occupied)<.02,"Living ki-rin remains opaque")
		rows.append({"item":0x3e9c,"angle":angle,"occupied":occupied,"transmitted":transmitted,"opaque_background_leaks":opaque_leaks})
	var file:=FileAccess.open("res://../outputs/equines/completion-appearance.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":rows,"renderer":RenderingServer.get_current_rendering_method(),"scope":"Real GPU images: nine client-only body presentations/dyes at two angles; ethereal ki-rin background transmission versus living opacity. Clothing and server permissions tested separately."},"\t"));file.close()
	print("EQUINE COMPLETION GPU: ",checks-failures," / ",checks);quit(1 if failures else 0)
