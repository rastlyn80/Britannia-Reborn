extends SceneTree
const Visual=preload("res://Presentation/CreatureVisual.gd")
const Mineral=preload("res://Presentation/CreatureMineralMaterial.gd")
var checks:=0
var failures:=0
var viewport: SubViewport
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func capture() -> Image:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	var result:=viewport.get_texture().get_image();result.convert(Image.FORMAT_RGBA8);return result
func changed(a: Image,b: Image) -> int:
	var count:=0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var first:=a.get_pixel(x,y);var second:=b.get_pixel(x,y)
			if Vector3(first.r-second.r,first.g-second.g,first.b-second.b).length()>.025:count+=1
	return count
func run() -> void:
	var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/elementals/preparation.json"))
	viewport=SubViewport.new();viewport.size=Vector2i(560,520);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("101920");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.65;Mineral.studio_reflections(env)
	var world:=WorldEnvironment.new();world.environment=env;viewport.add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-35,-40,0);sun.light_energy=1.6;viewport.add_child(sun)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;viewport.add_child(camera)
	var assets: Dictionary={};var samples: Array=[]
	var folder:=ProjectSettings.globalize_path("res://../outputs/creatures/elementals");DirAccess.make_dir_recursive_absolute(folder)
	for row: Dictionary in preparation.models:
		if row.status!="prepared":continue
		check(not row.get("mineral_surface",{}).is_empty(),"Every accepted ore/earth candidate declares its material")
		var actor:=Visual.new();actor.entry=row;viewport.add_child(actor);actor.set_process(false);actor.set_physics_process(false);actor.contact.enabled=false
		actor.rotation.y=-.7;actor.play("Idle",0.);actor.animator.seek(actor.animator.current_animation_length*.3,true);actor.animator.pause()
		var height:=float(row.stats.original.height_m);camera.size=height*1.6;camera.position=Vector3(0,height*.8,height*4.);camera.look_at(Vector3(0,height*.55,0.))
		var mesh: MeshInstance3D=actor.model.find_children("*","MeshInstance3D",true,false)[0]
		var arrays:=mesh.mesh.surface_get_arrays(0)
		check(arrays[Mesh.ARRAY_TANGENT]!=null and arrays[Mesh.ARRAY_TANGENT].size()==arrays[Mesh.ARRAY_VERTEX].size()*4,"Imported normal map has a real tangent basis")
		var material:=mesh.get_surface_override_material(0) as ShaderMaterial
		for role in ["albedo","normal","roughness"]:
			var texture: Texture2D=material.get_shader_parameter(role+"_texture")
			check(texture!=null and texture.get_width()==1024 and texture.get_height()==1024,"Pinned 1K "+role+" map is actually bound")
		var base:=await capture();DirAccess.make_dir_recursive_absolute(folder.path_join(str(row.kind)));base.save_png(folder.path_join(str(row.kind)+"/mineral-response.png"))
		material.set_shader_parameter("normal_strength",0.);var normal_off:=await capture()
		var normal_pixels:=changed(base,normal_off);check(normal_pixels>30,"Normal texture changes actual lit surface: "+str(row.kind))
		material.set_shader_parameter("normal_strength",float(row.mineral_surface.normal_strength))
		var metal: float=row.mineral_surface.metallic;var metal_pixels:=0
		if metal>0.:
			material.set_shader_parameter("metallic_strength",0.);var dielectric:=await capture();metal_pixels=changed(base,dielectric)
			check(metal_pixels>30,"Ore material has measurable metal reflection, not a leather surface")
		else:check(is_zero_approx(float(material.get_shader_parameter("metallic_strength"))),"Earth remains a dielectric stone surface")
		material.set_shader_parameter("metallic_strength",metal)
		material.set_shader_parameter("roughness_range",Vector2(.12,.12));var polished:=await capture();var rough_pixels:=changed(base,polished)
		check(rough_pixels>30,"Measured roughness response on the actual model")
		material.set_shader_parameter("roughness_range",Vector2(float(row.mineral_surface.roughness_range[0]),float(row.mineral_surface.roughness_range[1])))
		var delta:=Vector3(.35,0.,.2);actor.position+=delta;camera.position+=delta
		var translated:=await capture();var shifted:=changed(base,translated)
		check(shifted<150,"UV-space material follows the translated rig without swimming")
		camera.position-=delta
		samples.append({"kind":row.kind,"normal_response_pixels":normal_pixels,"metal_response_pixels":metal_pixels,"roughness_response_pixels":rough_pixels,"translation_changed_pixels":shifted})
		var path:="res://local-art/creatures/"+str(row.kind)+"-modern.gltf";assets[row.kind]={"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import"),"surface_parameters":row.mineral_surface.duplicate(true)}
		actor.free()
	check(samples.size()==8,"All eight prepared mineral identities have measured material response")
	var runtime: Dictionary={}
	for name in ["MineralAppearanceTests.gd","CreatureVisual.gd","CreatureMineralMaterial.gd","CreatureMineralSurface.gdshader","HumanHue.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var output:=FileAccess.open(folder.path_join("mineral-response.json"),FileAccess.WRITE);output.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"assets":assets,"runtime_sha256":runtime,"samples":samples,"scope":"Actual GPU map/tangent binding, normal, metallic and roughness response, plus translated UV-space stability. Not final anatomy, native gameplay or all lighting conditions."},"\t"));output.close()
	print("MINERAL MATERIAL RESPONSE: ",checks-failures," / ",checks);quit(1 if failures else 0)
