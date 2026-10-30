extends SceneTree
## Completed engine frames of this batch, using the real human/horse renderers.
var actors: Array=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(1600,1000)
	var stage:=Node3D.new();root.add_child(stage)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("243440");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color("c9d6df");environment.environment.ambient_light_energy=.55;environment.environment.tonemap_mode=Environment.TONE_MAPPER_AGX;stage.add_child(environment)
	var sky:=Sky.new();var sky_material:=ProceduralSkyMaterial.new();sky_material.sky_top_color=Color("738fa8");sky_material.sky_horizon_color=Color("d4dce1");sky_material.ground_bottom_color=Color("444b50");sky_material.ground_horizon_color=Color("8e979f");sky.sky_material=sky_material;environment.environment.sky=sky;environment.environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-25,0);light.light_energy=1.3;light.shadow_enabled=true;stage.add_child(light)
	var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(-20,145,0);fill.light_energy=.35;stage.add_child(fill)
	var floor_node:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(30,.1,30);floor_node.mesh=box;floor_node.position.y=-.05;var mat:=StandardMaterial3D.new();mat.albedo_color=Color("63716a");floor_node.material_override=mat;stage.add_child(floor_node)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;stage.add_child(camera)
	var canvas:=CanvasLayer.new();root.add_child(canvas);var label:=Label.new();label.position=Vector2(20,16);label.add_theme_font_size_override("font_size",24);canvas.add_child(label)
	var footer:=Label.new();footer.position=Vector2(20,958);footer.text="Male / female • native dyes + long hair • actual Godot render • local pose review";footer.add_theme_font_size_override("font_size",18);canvas.add_child(footer)
	for female in [false,true]:
		var actor:=preload("res://Presentation/HumanAvatar.gd").new();actor.initial_body=401 if female else 400;stage.add_child(actor);actor.set_physics_process(false);actor.set_process(false);actor.foot_contact.active=false;actor.human_visual.set_process(false);actors.append(actor)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../scripts/human-coverage-recipes.json"))
	var jobs: Array=data.assets.filter(func(row: Dictionary):return row.kind=="expansion35")
	if OS.get_cmdline_user_args().has("--weapons-only"):jobs=jobs.filter(func(row: Dictionary):return row.slot=="weapon")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/human-frontier"))
	for job: Dictionary in jobs:
		job.armoured=false
		var definition: Array=[int(job.graphics[0]),0]
		for mounted in [false,true]:
			for back in [false,true]:
				var key: String=job.key+("_armour" if job.armoured else "")+("_riding" if mounted else "_walking")+("_back" if back else "")
				label.text="BRITANNIA REBORN / "+str(job.key).replace("_"," ").capitalize()+" / "+("over plate" if job.armoured else "civilian")+" / "+("riding" if mounted else "walking")
				var tall_weapon: bool=job.slot=="weapon" and job.design!="book"
				camera.size=(4.5 if mounted else 3.6) if tall_weapon else (3.8 if mounted else 2.2)
				var centre:=Vector3(0,(1.95 if mounted else 1.35) if tall_weapon else (1.4 if mounted else .97),0);camera.position=centre+Vector3(0,.12,7);camera.look_at(centre)
				for i in actors.size():
					var actor: Node3D=actors[i]
					if not mounted and actor.horse_visual!=null:actor._finish_dismount()
					actor.appearance_seen=false;actor.position=Vector3((-1.4 if i==0 else 1.4) if mounted else (-.6 if i==0 else .6),0,0);actor.rotation_degrees.y=(145 if back else 35 if job.design=="book" else -35) if mounted else (160 if back else 35 if job.design=="book" else -12)
					var worn: Array=[{"id":0x1539,"layer":4},{"id":0x170b,"layer":3},{"id":0x203d,"layer":11,"hue":1147},{"id":int(definition[0]),"hue":0}]
					worn.append({"id":0x1415,"layer":13} if job.armoured else {"id":0x1517,"layer":5})
					if mounted:worn.append({"id":0x3ea0,"layer":25})
					actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn);actor.human_visual.cancel_action();actor.human_visual.play("Rider_Walk" if mounted else "Walk",0.);actor.human_visual.animator.seek(actor.human_visual.animator.current_animation_length*.23,true);actor.human_visual.animator.pause()
					assert(actor.human_visual.missing_art.is_empty())
					if mounted:
						actor.rider_contact.mode="seated";actor.rider_contact.seated_weight=1.;actor.horse_visual.animator.play("walk",0.);actor.horse_visual.animator.seek(.3,true);actor.horse_visual.animator.pause()
				for frame in 3:await process_frame
				await RenderingServer.frame_post_draw
				assert(root.get_texture().get_image().save_png("res://../outputs/human-frontier/"+key+".png")==OK)
				print("FRONTIER REVIEW ",key)
	print("FRONTIER REVIEW COMPLETE ",jobs.size()*4," frames");quit()
