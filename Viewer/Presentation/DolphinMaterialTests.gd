extends SceneTree
## Independent trial: real PBR/dye response, before the native route is installed.
const Marine=preload("res://Presentation/CreatureMarineMaterial.gd")
const ASSET="res://local-art/dolphin/dolphin.glb"
var checks:=0
var failures:=0
var viewport: SubViewport
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func picture(path: String="") -> Image:
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	var result:=viewport.get_texture().get_image();result.convert(Image.FORMAT_RGBA8)
	if not path.is_empty():result.save_png(path)
	return result
func difference(a: Image,b: Image) -> int:
	var count:=0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var first:=a.get_pixel(x,y);var second:=b.get_pixel(x,y)
			if first.a>.2 and Vector3(first.r-second.r,first.g-second.g,first.b-second.b).length()>.015:count+=1
	return count
func run() -> void:
	var paths:=["res://Presentation/DolphinMaterialTests.gd","res://Presentation/CreatureMarineMaterial.gd","res://Presentation/CreatureMarineSurface.gdshader","res://Presentation/HumanHue.gd"]
	var runtime: Dictionary={}
	for path in paths:runtime[path]=FileAccess.get_sha256(path)
	var asset_sha:=FileAccess.get_sha256(ASSET)
	var output:=ProjectSettings.globalize_path("res://../outputs/creatures/dolphin-trial");DirAccess.make_dir_recursive_absolute(output)
	viewport=SubViewport.new();viewport.size=Vector2i(900,640);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=3.6;camera.position=Vector3(4.,1.2,2.);viewport.add_child(camera);camera.look_at(Vector3(0.,.1,0.))
	var model: Node3D=load(ASSET).instantiate();viewport.add_child(model)
	var player: AnimationPlayer=model.find_children("*","AnimationPlayer",true,false)[0];player.play("Idle",0.);player.seek(.4,true);player.pause()
	var meshes:=model.find_children("*","MeshInstance3D",true,false);var images: Dictionary={}
	for hue in [0,53,0x8000|53,2305]:
		for mesh: MeshInstance3D in meshes:
			for surface in mesh.mesh.get_surface_count():
				var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
				var material:=Marine.build(source,hue,.32);mesh.set_surface_override_material(surface,material)
				check(material.get_shader_parameter("has_albedo")== (source.albedo_texture!=null),"Licensed source colour map is retained")
				check(material.get_shader_parameter("has_normal")== (source.normal_texture!=null),"Licensed normal map is retained")
				check(material.get_shader_parameter("partial_hue")==((hue&0x8000)!=0),"Raw partial-hue flag is retained")
				if source.resource_name.to_lower().contains("eye"):check(not material.get_shader_parameter("use_hue"),"Facial eye retains its own dark PBR surface under body dye")
		images[hue]=await picture(output+"/pbr-hue-"+str(hue)+".png")
	for hue in [53,0x8000|53,2305]:check(difference(images[0],images[hue])>300,"Native palette changes actual marine pixels: "+str(hue))
	for mesh: MeshInstance3D in meshes:
		for surface in mesh.mesh.get_surface_count():mesh.get_active_material(surface).set_shader_parameter("wetness",0.)
	var dry:=await picture(output+"/pbr-dry.png")
	check(difference(images[2305],dry)>20,"Wet PBR measurably changes actual source surfaces")
	for mesh: MeshInstance3D in meshes:
		for surface in mesh.mesh.get_surface_count():mesh.get_active_material(surface).set_shader_parameter("normal_strength",0.)
	var flat:=await picture(output+"/pbr-no-normal.png")
	check(difference(dry,flat)>20,"Source normal map measurably changes actual pixels")
	for path in paths:check(runtime[path]==FileAccess.get_sha256(path),"Marine runtime remains unchanged during testing")
	check(asset_sha==FileAccess.get_sha256(ASSET),"Independent mesh remains unchanged during testing")
	var file:=FileAccess.open(output+"/materials.json",FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"runtime_sha256":runtime,"asset_sha256":asset_sha,"scope":"Independent source-map and raw dye/wet/normal GPU response; not native or support/corpse acceptance."},"  "));file.close()
	print("DOLPHIN MATERIALS: ",checks," checks / ",failures," failures");quit(1 if failures else 0)
