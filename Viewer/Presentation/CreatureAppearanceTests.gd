extends SceneTree
const Visual=preload("res://Presentation/CreatureVisual.gd")
var family:="bruins"
var viewport: SubViewport
var checks:=0
var failures:=0
var rows: Array=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--family="):family=arg.trim_prefix("--family=")
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func capture() -> Image:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	var result:=viewport.get_texture().get_image();result.convert(Image.FORMAT_RGBA8);return result
func run() -> void:
	var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/"+family+"/preparation.json"))
	viewport=SubViewport.new();viewport.size=Vector2i(480,420);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();var env:=environment.environment;env.background_mode=Environment.BG_COLOR;env.background_color=Color.BLACK;env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.8;viewport.add_child(environment)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-35,0);sun.light_energy=1.2;viewport.add_child(sun)
	if preparation.models.any(func(row: Dictionary):return not row.get("mineral_surface",{}).is_empty()):preload("res://Presentation/CreatureMineralMaterial.gd").studio_reflections(env)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;viewport.add_child(camera)
	for record: Dictionary in preparation.models:
		if record.status!="prepared":continue
		var actor:=Visual.new();actor.entry=record;viewport.add_child(actor);actor.set_process(false);actor.set_physics_process(false);actor.contact.enabled=false
		var height:=float(record.stats.original.height_m);camera.size=height*3.;camera.position=Vector3(0,height*1.4,height*5.);camera.look_at(Vector3(0,height*.5,0))
		var largest_cutout_fraction:=0.
		for clip in ["Walk","Run","Attack"]:
			for angle in [-.8,PI/2.]:
				actor.rotation.y=angle;actor.apply_identity(0,0);actor.play(clip,0.);actor.animator.seek(actor.animator.current_animation_length*.35,true);actor.animator.pause()
				var base:=await capture();actor.apply_identity(0,53);var dyed:=await capture();var occupied:=0;var changed:=0
				for y in range(0,420,2):
					for x in range(0,480,2):
						var a:=base.get_pixel(x,y);var b:=dyed.get_pixel(x,y)
						if maxf(a.r,maxf(a.g,a.b))<.04:continue
						occupied+=1
						if Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length()>.025:changed+=1
				check(occupied>150,"Actual creature surface visible: "+str(record.kind))
				check(float(changed)/maxi(1,occupied)>.35,"Native full hue visibly recolours actual creature: "+str(record.kind))
				var dependencies: Dictionary={}
				var cutout: Dictionary={}
				for name: String in record.get("art_dependency_sha256",{}):dependencies[name]=FileAccess.get_sha256("res://local-art/creatures/"+name)
				if not str(record.get("source_alpha_texture","")).is_empty():
					actor.apply_identity(0,0)
					set_mask_probe(actor,true,true);var masked:=await capture()
					set_mask_probe(actor,true,false);var solid:=await capture();var gaps:=0;var solid_pixels:=0
					for y in range(0,420,2):
						for x in range(0,480,2):
							var a:=masked.get_pixel(x,y);var b:=solid.get_pixel(x,y)
							if maxf(b.r,maxf(b.g,b.b))>.04:
								solid_pixels+=1
								if maxf(a.r,maxf(a.g,a.b))<.04:gaps+=1
					var fraction:=float(gaps)/maxi(1,solid_pixels)
					largest_cutout_fraction=maxf(largest_cutout_fraction,fraction)
					cutout={"pixels":gaps,"solid_pixels":solid_pixels,"fraction":fraction}
					# Tiny tooth/ornament edge cutouts do not cover wing-sized areas.
					# Both policies still fail when the actual source mask is lost.
					check(gaps>(0 if record.get("source_alpha_scope","")=="fine_edges" else 10),"Source opacity creates measured visible gaps in each sampled view: "+str(record.kind))
					set_mask_probe(actor,false,true)
				rows.append({"kind":record.kind,"clip":clip,"angle":angle,"occupied_pixels":occupied,"dyed_fraction":float(changed)/maxi(1,occupied),"source_cutout":cutout,"asset_sha256":FileAccess.get_sha256("res://local-art/creatures/"+str(record.kind)+"-modern.gltf"),"import_sha256":FileAccess.get_sha256("res://local-art/creatures/"+str(record.kind)+"-modern.gltf.import"),"art_dependency_sha256":dependencies})
		if not str(record.get("source_alpha_texture","")).is_empty():
			# Foreshortening changes the fraction of visible wing area. Require
			# real gaps in every view and a substantial cutout in the view set.
			check(largest_cutout_fraction>(.0001 if record.get("source_alpha_scope","")=="fine_edges" else .03),"View set exposes declared source alpha cutouts: "+str(record.kind))
		actor.free()
	check(not rows.is_empty(),"At least one model rendered")
	var folder:="res://../outputs/creatures/"+family;DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var file:=FileAccess.open(folder+"/appearance.json",FileAccess.WRITE);file.store_string(JSON.stringify({"family":family,"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"samples":rows,"scope":"Actual GPU visibility and full native dye response; precise UV/anatomy review and partial dyes remain separate."},"\t"));file.close()
	print("CREATURE GPU / ",family,": ",checks-failures," / ",checks);quit(1 if failures else 0)
func set_mask_probe(actor: Node3D,probe: bool,mask_enabled: bool) -> void:
	for mesh: MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
		if mesh.has_meta("source_death_flash"):continue
		for surface in mesh.mesh.get_surface_count():
			var material:=mesh.get_surface_override_material(surface) as ShaderMaterial
			material.set_shader_parameter("alpha_probe",probe);material.set_shader_parameter("use_source_alpha",mask_enabled)
