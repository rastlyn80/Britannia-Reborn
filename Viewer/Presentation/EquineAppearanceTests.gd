extends SceneTree
const Horse=preload("res://Presentation/HorseVisual.gd")
const Registry=preload("res://Presentation/EquineRegistry.gd")
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
	return viewport.get_texture().get_image()
func difference(a: Color,b: Color) -> float:return Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()
func changed(a: Image,b: Image) -> int:
	var count:=0
	for y in 420:
		for x in 480:
			if difference(a.get_pixel(x,y),b.get_pixel(x,y))>.04:count+=1
	return count
func run() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(480,420);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var stage:=Node3D.new();viewport.add_child(stage)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();var env:=environment.environment;env.background_mode=Environment.BG_COLOR;env.background_color=Color.BLACK;env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.7;stage.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-35,0);sun.light_energy=1.2;stage.add_child(sun)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.4;camera.position=Vector3(0,1.7,6.);stage.add_child(camera);camera.look_at(Vector3(0,1.2,0))
	var horse:=Horse.new();stage.add_child(horse);horse.set_process(false);horse.set_physics_process(false);horse.contact.enabled=false;horse.animator.play("walk",0.);horse.animator.seek(.25,true);horse.animator.pause()
	for body: int in Registry.BODIES:
		for angle in [-.8,PI/2.]:
			horse.rotation.y=angle;horse.apply_identity(body,0)
			var original:=await capture()
			var mesh: MeshInstance3D=horse.model.find_children("*","MeshInstance3D",true,false)[0]
			mesh.get_active_material(0).set_shader_parameter("show_regions",true);var mask:=await capture();mesh.get_active_material(0).set_shader_parameter("show_regions",false)
			# Hide fittings for the region test so their depth is not mistaken
			# for a source tack region. Visibility itself is tested separately.
			var fittings: Array=horse.skeleton.get_children().filter(func(node: Node):return node.has_meta("equine_fitting"))
			for node: Node3D in fittings:node.visible=false
			var no_fittings:=await capture();var fitting_pixels:=changed(original,no_fittings)
			if str(Registry.BODIES[body][1]) in ["unicorn","pack"]:check(fitting_pixels>35,"Horn/panniers are visible in real rendered frames at both angles")
			var fur: Array[Vector2i]=[];var tack: Array[Vector2i]=[]
			for y in range(2,418,2):
				for x in range(2,478,2):
					var p:=Vector2i(x,y);var a:=original.get_pixelv(p)
					if difference(a,no_fittings.get_pixelv(p))>.005:continue
					if mask.get_pixelv(p).r>.98:fur.append(p)
					elif mask.get_pixelv(p).r<.001 and maxf(a.r,maxf(a.g,a.b))>.06:tack.append(p)
			check(fur.size()>100 and tack.size()>100,"Each profile has real visible coat and tack samples")
			for hue in [53,1153]:
				horse.apply_identity(body,hue);var dyed:=await capture();var retained:=0;var recoloured:=0
				for p in tack:
					if difference(no_fittings.get_pixelv(p),dyed.get_pixelv(p))<.025:retained+=1
				for p in fur:
					if difference(no_fittings.get_pixelv(p),dyed.get_pixelv(p))>.025:recoloured+=1
				var retention:=float(retained)/maxi(1,tack.size());var change:=float(recoloured)/maxi(1,fur.size())
				check(retention>.98,"Dye changes retain source tack on every opaque equine")
				check(change>.65,"Server dyes visibly recolour every opaque equine coat")
				rows.append({"body":body,"angle":angle,"hue":hue,"tack_retained":retention,"fur_changed":change,"fitting_pixels":fitting_pixels})
			for node: Node3D in fittings:node.visible=true
	for item: int in Registry.ETHEREALS:
		horse.apply_identity(Horse.horse_body(item),0x4001,item)
		for node: Node3D in horse.skeleton.get_children():
			if node.has_meta("equine_fitting"):node.visible=false
		var spectral_black:=await capture();env.background_color=Color("a02954");var spectral_pink:=await capture()
		horse.apply_identity(Horse.horse_body(item),0)
		for node: Node3D in horse.skeleton.get_children():
			if node.has_meta("equine_fitting"):node.visible=false
		var opaque_pink:=await capture();env.background_color=Color.BLACK;var opaque_black:=await capture()
		var occupied:=0;var transmissive:=0;var opaque_changed:=0
		for y in range(2,418,2):
			for x in range(2,478,2):
				var p:=Vector2i(x,y);var a:=opaque_black.get_pixelv(p)
				if maxf(a.r,maxf(a.g,a.b))<.08:continue
				occupied+=1
				if difference(spectral_black.get_pixelv(p),spectral_pink.get_pixelv(p))>.03:transmissive+=1
				if difference(opaque_black.get_pixelv(p),opaque_pink.get_pixelv(p))>.03:opaque_changed+=1
		check(occupied>100 and float(transmissive)/occupied>.65,"Ethereal horse actually transmits the background through its body")
		check(float(opaque_changed)/maxi(1,occupied)<.02,"Returning from ethereal to ordinary profile restores opacity")
		rows.append({"ethereal_item":item,"occupied":occupied,"transmissive_pixels":transmissive,"ordinary_background_leak":opaque_changed})
	stage.free();viewport.queue_free();await process_frame
	var file:=FileAccess.open("res://../outputs/equines/appearance-validation.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":rows,"scope":"Real Forward+ differential captures: all 15 opaque profiles, dyes/tack, horn and pannier visibility; two ethereal transmissions and opaque restoration. Finite views, not final art approval."},"\t"));file.close()
	print("EQUINE APPEARANCE GPU: ",checks," checks / ",failures," failures");quit(1 if failures else 0)
