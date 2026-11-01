extends SceneTree
## Retained CC0 rig/actions, authored flame ribbons and radial ash footprint.
const CARRIER="res://Art/Creatures/Water/water-elemental.scn"
const OUTPUT="res://local-art/fire/fire-modern.scn"
func _initialize() -> void:call_deferred("run")
func own(node: Node,scene: Node) -> void:
	for child in node.get_children():child.owner=scene;own(child,scene)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var carrier_scene:=load(CARRIER) as PackedScene
	if carrier_scene==null:quit(1);return
	var actor:=carrier_scene.instantiate() as Node3D;actor.name="FireElemental";root.add_child(actor)
	var rig:=actor.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	var body:=actor.find_child("FluidBody",true,false) as MeshInstance3D;var dust:=actor.find_child("Puddle",true,false) as MeshInstance3D
	preload("res://Presentation/FireFlameGeometry.gd").install(body,rig)
	var player:=actor.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	var library: AnimationLibrary=player.get_animation_library("").duplicate(true);player.remove_animation_library("");player.add_animation_library("",library)
	for category: String in library.get_animation_list():
		var animation: Animation=library.get_animation(category)
		for track in animation.get_track_count():
			var path:=str(animation.track_get_path(track)).replace("FluidBody:","FireBody:").replace("Puddle:","Ash:")
			animation.track_set_path(track,NodePath(path))
		if category.begins_with("Death"):
			animation.length=1.4
			for track in animation.get_track_count():
				var path:=str(animation.track_get_path(track));var type:=animation.track_get_type(track)
				if type==Animation.TYPE_SCALE_3D and path.ends_with(":root"):
					for key in range(animation.track_get_key_count(track)-1,-1,-1):animation.track_remove_key(track,key)
					for pair in [[0.,Vector3.ONE],[.35,Vector3.ONE*.8],[.8,Vector3.ONE*.28],[1.4,Vector3.ONE*.08]]:animation.scale_track_insert_key(track,pair[0],pair[1])
				elif path.ends_with("FireBody:visible") or path.ends_with("Ash:visible"):
					for key in range(animation.track_get_key_count(track)-1,-1,-1):animation.track_remove_key(track,key)
					animation.track_insert_key(track,0.,path.ends_with("FireBody:visible"));animation.track_insert_key(track,.95 if path.ends_with("FireBody:visible") else .45,path.ends_with("Ash:visible"))
	body.name="FireBody";dust.name="Ash"
	for mesh: MeshInstance3D in [body,dust]:
		mesh.mesh=mesh.mesh.duplicate(true);mesh.material_override=null;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material:=ShaderMaterial.new();var shader:=Shader.new();shader.code=FileAccess.get_file_as_string("res://Presentation/FireElementalSurface.gdshader");material.shader=shader;material.set_shader_parameter("dust",mesh==dust)
		for surface in mesh.mesh.get_surface_count():mesh.mesh.surface_set_material(surface,material)
	player.clear_caches();player.play("Idle",0.);player.seek(0.,true);player.pause();rig.force_update_all_bone_transforms();actor.scene_file_path="";own(actor,actor)
	var packed:=PackedScene.new();assert(packed.pack(actor)==OK);assert(ResourceSaver.save(packed,OUTPUT)==OK)
	var clips: Dictionary={}
	for category: String in library.get_animation_list():
		var animation: Animation=library.get_animation(category);clips[category]={"duration":animation.length,"loop":animation.loop_mode==Animation.LOOP_LINEAR,"origin":"Private authored flame dissipation and settling ash trial" if category.begins_with("Death") else "Retained CC0 Quaternius UAL1 motion through the pinned Water carrier; body replaced, project-authored radial footprint retained as ash"}
	var arrays:=body.mesh.surface_get_arrays(0)
	var file:=FileAccess.open(OUTPUT.get_base_dir()+"/preparation.json",FileAccess.WRITE);file.store_string(JSON.stringify({"bones":rig.get_bone_count(),"vertices":arrays[Mesh.ARRAY_VERTEX].size(),"triangles":arrays[Mesh.ARRAY_INDEX].size()/3,"clips":clips,"carrier_sha256":FileAccess.get_sha256(CARRIER),"recipe_sha256":FileAccess.get_sha256("res://Presentation/PrepareFireElemental.gd"),"geometry_sha256":FileAccess.get_sha256("res://Presentation/FireFlameGeometry.gd"),"shader_sha256":FileAccess.get_sha256("res://Presentation/FireElementalSurface.gdshader"),"asset_sha256":FileAccess.get_sha256(OUTPUT),"shader_displacement_margin":.08,"scope":"Independent GPL crossed flame ribbons, procedural fire shader and retained project-authored radial footprint used as ash; retained CC0 rig/UAL actions from existing public Water carrier with its body replaced. No source game marker/texture in this scene. No installed route or native coverage yet."},"\t"));file.close();print("PRIVATE FIRE TRIAL PREPARED: ",rig.get_bone_count()," bones / ",arrays[Mesh.ARRAY_VERTEX].size()," vertices / ",clips.size()," categories; no route installed");quit()
