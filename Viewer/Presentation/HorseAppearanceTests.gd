extends SceneTree
## Actual GPU differential checks: coat colours and raw hue flags, tack retained.
const Horse=preload("res://Presentation/HorseVisual.gd")
var viewport: SubViewport
var checks:=0
var failures:=0
var rows: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func capture() -> Image:
	await process_frame;await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func materials(horse: Node3D,regions: bool) -> void:
	for mesh: MeshInstance3D in horse.model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():mesh.get_active_material(surface).set_shader_parameter("show_regions",regions)
func run() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(480,480);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var stage:=Node3D.new();viewport.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color.BLACK;env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65;stage.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-35,0);sun.light_energy=1.;stage.add_child(sun)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.;camera.position=Vector3(0,1.6,6.);stage.add_child(camera);camera.look_at(Vector3(0,1.1,0))
	var horse:=Horse.new();stage.add_child(horse);horse.set_physics_process(false);horse.set_process(false);horse.animator.seek(0.,true);horse.animator.pause()
	var coat_means: Dictionary={}
	for body: int in Horse.BODIES:
		for angle in [-.8,.8,2.3,-2.3]:
			horse.rotation.y=angle;horse.apply_identity(body,0)
			var original:=await capture()
			materials(horse,true);var mask:=await capture();materials(horse,false)
			var fur: Array[Vector2i]=[];var tack: Array[Vector2i]=[]
			for y in range(2,478,2):
				for x in range(2,478,2):
					var p:=Vector2i(x,y);var c:=original.get_pixelv(p);var region:=mask.get_pixelv(p).r
					if region>.98:fur.append(p)
					elif region<.001 and maxf(c.r,maxf(c.g,c.b))>.06:tack.append(p)
			check(fur.size()>100 and tack.size()>100,"The rendered horse has independently visible coat and retained tack regions")
			var mean:=Vector3.ZERO
			for p in fur:
				var c:=original.get_pixelv(p);mean+=Vector3(c.r,c.g,c.b)/float(fur.size())
			if angle==-.8:coat_means[body]=mean
			for hue in [53,1153,0x8000|53]:
				horse.apply_identity(body,hue);var dyed:=await capture();var retained:=0;var changed:=0
				for p in tack:
					var a:=original.get_pixelv(p);var b:=dyed.get_pixelv(p)
					if Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()<.025:retained+=1
				for p in fur:
					var a:=original.get_pixelv(p);var b:=dyed.get_pixelv(p)
					if Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()>.025:changed+=1
				var retention:=float(retained)/maxi(1,tack.size());var change:=float(changed)/maxi(1,fur.size())
				check(retention>.98,"Native hue changes preserve over 98% of the unmasked tack pixels")
				var expected: bool=hue<0x8000 or body==0xe2
				check(change>.65 if expected else change<.05,"Full and partial native hues recolour the appropriate coat regions")
				rows.append({"body":body,"hue":hue,"angle":angle,"tack_retained_fraction":retention,"coat_changed_fraction":change,"fur_samples":fur.size(),"tack_samples":tack.size()})
				if failures<=3 and failures>0:dyed.save_png("res://../outputs/horse-polish/appearance-debug-%d.png"%failures)
	var ids:=Horse.BODIES.keys()
	for i in ids.size():
		for j in range(i+1,ids.size()):check((coat_means[ids[i]] as Vector3).distance_to(coat_means[ids[j]])>.025,"Each native base coat has a distinct rendered appearance")
	horse.free();camera.size=4.2;camera.position=Vector3(0,2.2,6.);camera.look_at(Vector3(0,1.5,0))
	var white:=StandardMaterial3D.new();white.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;white.albedo_color=Color.WHITE;white.cull_mode=BaseMaterial3D.CULL_DISABLED
	for female in [false,true]:
		for family in [[0x1415,0x1410,0x1411,0x1414,0x170b],[0x1f03,0x1539,0x13c6,0x170b]]:
			var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=401 if female else 400;stage.add_child(actor);actor.set_physics_process(false)
			var worn: Array=[]
			for id in family:worn.append({"id":id})
			actor.apply_server_appearance({"body":actor.initial_body},worn)
			var mounted: Array=worn.duplicate(true);mounted.append({"id":0x3e9f,"layer":25})
			for phase in range(4):
				if phase==0:actor.apply_server_appearance({"body":actor.initial_body},mounted);actor.rider_contact.begin_mount(false)
				elif phase==1:actor.apply_server_appearance({"body":actor.initial_body},worn);actor.rider_contact.progress=.5
				elif phase==2:actor._finish_dismount()
				else:actor.apply_server_appearance({"body":actor.initial_body},mounted)
				actor.animate(false,0.,.016,0.);actor.animator.seek(.1,true);actor.animator.pause()
				if actor.rider_contact!=null:actor.rider_contact.transition_duration=100000.
				var meshes:=actor.find_children("*","MeshInstance3D",true,false);var states:={}
				var base: MeshInstance3D=actor.human_visual.model.find_children("Body*","MeshInstance3D",true,false)[0]
				for mesh: MeshInstance3D in meshes:
					states[mesh]={"visible":mesh.visible,"material":mesh.material_override};mesh.material_override=white
					if not actor.human_visual.is_ancestor_of(mesh):mesh.visible=false
				var actual:=await capture()
				for mesh: MeshInstance3D in meshes:mesh.visible=mesh==base
				var reference:=await capture();var occupied:=0;var missing:=0
				for y in 480:
					for x in 480:
						if reference.get_pixel(x,y).r>.95:
							occupied+=1
							if actual.get_pixel(x,y).r<.95:missing+=1
				var fraction:=1.-float(missing)/maxi(1,occupied)
				check(occupied>300 and fraction>.98,"The normal rendered frame retains the complete human silhouette through dismount/rebuild/remount")
				rows.append({"female":female,"outfit":family,"transition_state":phase,"body_reference_pixels":occupied,"body_occupancy":fraction})
				for mesh: MeshInstance3D in meshes:mesh.visible=states[mesh].visible;mesh.material_override=states[mesh].material
			actor.free()
	stage.free();viewport.queue_free();await process_frame
	var file:=FileAccess.open("res://../outputs/horse-polish/appearance-validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":rows,"scope":"GPU colour differences across four base coats, three full/partial raw hues and four angles; retained tack/coat regions; 16 full-human silhouette checks across mounted/dismount/rebuilt/remount states on both sexes in plate/robe. Normal completed render frames. Artistic PBR interpretation, not pixel-identical UO artwork."},"\t"));file.close()
	print("HORSE APPEARANCE GPU: ",checks," checks / ",failures," failures");quit(1 if failures else 0)
