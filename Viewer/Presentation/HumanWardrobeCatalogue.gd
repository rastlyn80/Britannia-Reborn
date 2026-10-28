extends SceneTree
var catalogue: Dictionary
var actors: Array=[]
var viewport: SubViewport
var camera: Camera3D
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var file:="res://../outputs/human-wardrobe-batch/jobs.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--jobs="):file=arg.substr(7)
	catalogue=JSON.parse_string(FileAccess.get_file_as_string(file))
	viewport=SubViewport.new();viewport.size=Vector2i(1000,1100);viewport.own_world_3d=true;viewport.msaa_3d=Viewport.MSAA_4X
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var stage:=Node3D.new();viewport.add_child(stage)
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("22323e")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color("c9d6df");env.environment.ambient_light_energy=.5
	env.environment.tonemap_mode=Environment.TONE_MAPPER_AGX;stage.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-25,0);sun.light_energy=1.1;sun.shadow_enabled=true;stage.add_child(sun)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-20,140,0);fill.light_energy=.25;stage.add_child(fill)
	var floor_node:=MeshInstance3D.new();var floor_mesh:=BoxMesh.new();floor_mesh.size=Vector3(20,.1,20);floor_node.mesh=floor_mesh;floor_node.position.y=-.05
	var floor_mat:=StandardMaterial3D.new();floor_mat.albedo_color=Color("53616a");floor_node.material_override=floor_mat;stage.add_child(floor_node)
	for female in [false,true]:
		for i in 2:
			var actor:=preload("res://Presentation/HumanVisual.gd").new();actor.female=female;stage.add_child(actor);actors.append(actor);actor.visible=false
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;stage.add_child(camera)
	var audit: Array=[]
	for job: Dictionary in catalogue.jobs:
		for actor in actors:actor.visible=false
		var counts:={false:0,true:0}
		viewport.size=Vector2i(int(job.size[0]),int(job.size[1]));camera.size=float(job.height)
		camera.position=Vector3(0,float(job.center)+.06,5.);camera.look_at(Vector3(0,float(job.center),0))
		for person: Dictionary in job.people:
			var female: bool=person.female;var index: int=(2 if female else 0)+counts[female];counts[female]+=1
			var actor: Node3D=actors[index];actor.visible=true;actor.position=Vector3(float(person.x),0,0);actor.rotation_degrees.y=float(person.angle)
			for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):mesh.visible=not mesh.name.begins_with("Eyelash")
			actor.appearance_key=""
			actor.set_skin(int(person.skin));actor.set_equipment(person.worn)
			assert(actor.missing_art.is_empty(),"Missing art in catalogue "+str(job.key))
			actor.current_clip="";actor.play(str(person.clip),0.);actor.animator.seek(actor.animator.current_animation_length*float(person.phase),true);actor.animator.pause()
			audit.append({"key":job.key,"female":female,"worn":person.worn,"missing_art":actor.missing_art,"clip":actor.animator.current_animation})
		if job.get("prop_only",false):
			var actor: Node3D=actors[0];var bounds:=AABB();var first:=true
			var bone: int=actor.skeleton.find_bone("hand_r")
			for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
				mesh.visible=mesh.name.begins_with("Extra_"+str(job.key))
				if not mesh.visible:continue
				var bind:=Transform3D.IDENTITY
				for index in mesh.skin.get_bind_count():
					if mesh.skin.get_bind_name(index)=="hand_r":bind=mesh.skin.get_bind_pose(index)
				var transform: Transform3D=actor.skeleton.global_transform*actor.skeleton.get_bone_global_pose(bone)*bind
				var posed: AABB=transform*mesh.mesh.get_aabb()
				bounds=posed if first else bounds.merge(posed);first=false
			assert(not first,"Missing isolated equipment mesh")
			var middle:=bounds.get_center()
			camera.size=maxf(bounds.size.y,bounds.size.x/((float(viewport.size.x))/viewport.size.y))*1.4
			camera.position=middle+Vector3(0,0,5.);camera.look_at(middle)
		for frame in 6:await process_frame
		await RenderingServer.frame_post_draw
		var path: String=str(catalogue.output)+"/"+str(job.key)+".png"
		assert(viewport.get_texture().get_image().save_png(path)==OK,"Could not save catalogue render")
		print("CATALOGUE ",job.key)
	var report:=FileAccess.open(str(catalogue.output)+"/render-audit.json",FileAccess.WRITE);report.store_string(JSON.stringify(audit,"\t"));report.close()
	print("CATALOGUE COMPLETE ",catalogue.jobs.size());quit()
