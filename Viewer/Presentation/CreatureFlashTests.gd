extends SceneTree
const Visual=preload("res://Presentation/CreatureVisual.gd")
const Bounds=preload("res://Presentation/SkinGeometry.gd")
var viewport: SubViewport
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(90.).timeout.connect(func():push_error("Death flash render timed out");quit(1))
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func capture() -> Image:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	var result:=viewport.get_texture().get_image();result.convert(Image.FORMAT_RGBA8);return result
func run() -> void:
	print("FLASH: loading source actor")
	var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/spirits/preparation.json"))
	var record: Dictionary=preparation.models.filter(func(row: Dictionary):return row.kind=="spirits_blade_spirit")[0]
	viewport=SubViewport.new();viewport.size=Vector2i(600,600);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("15232d");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.8;viewport.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-35,0);sun.light_energy=1.2;viewport.add_child(sun)
	var actor:=Visual.new();actor.entry=record;viewport.add_child(actor);actor.set_process(false);actor.set_physics_process(false);actor.contact.enabled=false;actor.rotation.y=-.7
	var height:=float(record.stats.original.height_m)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=height*3.;viewport.add_child(camera);camera.position=Vector3(0.,height*1.4,height*5.);camera.look_at(Vector3(0.,height*.65,0.))
	var plane:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(100.,.1,100.);plane.mesh=box;plane.position.y=-.05;var floor_material:=StandardMaterial3D.new();floor_material.albedo_color=Color("273b43");floor_material.roughness=1.;plane.material_override=floor_material;viewport.add_child(plane)
	check(actor.death_flashes.size()==1,"Recovered flash is a distinct mesh on the original rig")
	var body: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0]
	check(not body.has_meta("source_death_flash"),"Effect is excluded from actor floor and skin bounds")
	var samples: Array=[];var visible_phases:=0;var tinted_phases:=0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/creatures/spirits/spirits_blade_spirit"))
	for phase in [0.,.1,.25,.4,.5,.6,.75,.9,1.]:
		print("FLASH: rendering phase ",phase)
		var signals: Array=[]
		for hue in [0,53]:
			actor.apply_identity(574,hue);actor.play("Death",0.);actor.animator.seek(actor.animator.current_animation_length*phase,true);actor.animator.pause();actor.update_death_effect()
			var before:=Bounds.deformed_bounds(body,actor.skeleton);var on:=await capture()
			for flash in actor.death_flashes:flash.visible=false
			var off:=await capture();var changed:=0;var delta:=Vector3.ZERO
			for y in range(0,600,2):
				for x in range(0,600,2):
					var a:=on.get_pixel(x,y);var b:=off.get_pixel(x,y);var difference:=Vector3(a.r-b.r,a.g-b.g,a.b-b.b)
					if difference.length()>.025:changed+=1;delta+=difference
			check(Bounds.deformed_bounds(body,actor.skeleton).is_equal_approx(before),"Flash visibility never changes actor bounds")
			if hue==0 and changed>10:
				visible_phases+=1;on.save_png(ProjectSettings.globalize_path("res://../outputs/creatures/spirits/spirits_blade_spirit/effect-death-%.2f.png"%phase))
			if phase==0. or phase==1.:check(changed==0,"Death flash is absent at resting endpoints")
			signals.append(delta);samples.append({"phase":phase,"hue":hue,"changed_pixels":changed,"effect_signal":str(delta)})
		if signals[0].distance_to(signals[1])>1.:tinted_phases+=1
	check(visible_phases>=2,"Recovered death trajectory produces an actual visible flash over multiple phases")
	check(tinted_phases>=2,"Native hue visibly recolours the recovered flash")
	for clip in ["Idle","Walk","Run","Attack"]:
		actor.play(clip,0.);actor.animator.seek(actor.animator.current_animation_length*.5,true);actor.animator.pause();actor.update_death_effect()
		check(actor.death_flashes.all(func(mesh: MeshInstance3D):return not mesh.visible),"Death-only geometry stays hidden during "+clip)
	var inputs: Dictionary={}
	for file in ["CreatureFlashTests.gd","CreatureVisual.gd","CreatureFlashSurface.gdshader"]:inputs[file]=FileAccess.get_sha256("res://Presentation/"+file)
	var report:={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"asset_sha256":FileAccess.get_sha256("res://local-art/creatures/spirits_blade_spirit-modern.gltf"),"import_sha256":FileAccess.get_sha256("res://local-art/creatures/spirits_blade_spirit-modern.gltf.import"),"runtime_sha256":inputs,"samples":samples,"scope":"Actual GPU death flash, raw hue response, living-state exclusion and separate actor bounds; authored unlit surface on recovered mesh/joint motion."}
	var output:=FileAccess.open("res://../outputs/creatures/spirits/death-effect.json",FileAccess.WRITE);output.store_string(JSON.stringify(report,"\t"));output.close()
	print("CREATURE DEATH FLASH: ",checks-failures," / ",checks,"; visible phases=",visible_phases);quit(1 if failures else 0)
