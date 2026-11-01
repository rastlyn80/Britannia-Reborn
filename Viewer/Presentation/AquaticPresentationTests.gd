extends SceneTree
## Native water-plane anchoring and actual wet/alpha surfaces, not land locomotion.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const FILES=["AquaticPresentationTests.gd","CreatureVisual.gd","HumanAvatar.gd","LegacyAvatar.gd","SourceMountContact.gd","CreatureCutoutSurface.gdshader","CreatureMarineMaterial.gd","CreatureMarineSurface.gdshader","SkinGeometry.gd","CorpseModels.gd"]
var family:="krakens"
var candidate_path:=""
var checks:=0
var failures:=0
var viewport: SubViewport
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--family="):family=arg.trim_prefix("--family=")
		if arg.begins_with("--candidate="):candidate_path=arg.trim_prefix("--candidate=")
	call_deferred("run")
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
	var runtime: Dictionary={}
	for name in FILES:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var path:="res://local-art/creatures/"+family+"/preparation.json" if candidate_path.is_empty() else candidate_path
	var preparation_sha:=FileAccess.get_sha256(path)
	var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not candidate_path.is_empty():
		preparation.status="prepared";preparation={"models":[preparation]}
	var output:=ProjectSettings.globalize_path("res://../outputs/creatures/"+(family if candidate_path.is_empty() else "dolphin-trial")+"/aquatic")
	DirAccess.make_dir_recursive_absolute(output)
	Registry.load_index()
	viewport=SubViewport.new();viewport.size=Vector2i(768,640);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	for environment: WorldEnvironment in viewport.find_children("*","WorldEnvironment",true,false):preload("res://Presentation/CreatureMineralMaterial.gd").studio_reflections(environment.environment)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.near=.001;viewport.add_child(camera)
	var assets: Dictionary={};var samples: Array=[]
	for record: Dictionary in preparation.models:
		if record.status!="prepared":continue
		check(record.movement_mode=="native_waterline","Explicit aquatic support policy")
		var asset:=Registry.asset_path(record)
		assets[record.kind]={"asset_sha256":FileAccess.get_sha256(asset),"import_sha256":FileAccess.get_sha256(asset+".import")}
		for identity: Dictionary in record.bodies:Registry.entries[int(identity.body)]=record
		var body:=int(record.bodies[0].body)
		var avatar:=Avatar.new();avatar.initial_body=body;viewport.add_child(avatar);avatar.set_physics_process(false)
		avatar.apply_server_appearance({"body":body,"hue":0},[])
		var visual: Node3D=avatar.horse_visual;visual.set_process(false);visual.set_physics_process(false)
		var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0]
		var rig: Skeleton3D=visual.skeleton;var player: AnimationPlayer=visual.animator
		check(visual.contact.feet.is_empty(),"Aquatic rig has no invented stance-foot IK")
		var span:=float(record.stats.original.bind_diagonal_m);camera.size=span*1.05;camera.position=Vector3(span*.65,span*.45,span*.85);camera.look_at(Vector3.ZERO)
		player.play("Idle",0.);player.seek(.3,true);player.pause()
		var material:=mesh.get_active_material(0) as ShaderMaterial
		var marine: bool=record.get("surface_kind","")=="marine_pbr"
		check(material!=null and material.shader==(preload("res://Presentation/CreatureMarineSurface.gdshader") if marine else preload("res://Presentation/CreatureCutoutSurface.gdshader")),"Actual mesh retains its explicit wet PBR/opacity policy")
		if material!=null and (record.has("source_alpha_texture") or marine):
			check(is_equal_approx(float(material.get_shader_parameter("wetness")),.7),"Living sea surface opts into wet PBR")
			var wet:=await picture(output+"/"+str(record.kind)+"-wet.png")
			material.set_shader_parameter("wetness",0.);var dry:=await picture()
			var pixels:=difference(wet,dry);check(pixels>20,"Wet response measurably changes actual pixels")
			material.set_shader_parameter("wetness",.7);samples.append({"kind":record.kind,"wet_pixels":pixels})
		for clip in ["Idle","Walk","Run","Attack","Attack2","Attack3","Cast","Jump","Roll","Death"]:
			if not player.has_animation(clip):continue
			player.play(clip,0.);player.seek(player.get_animation(clip).length*.5,true);player.pause()
			await picture(output+"/"+str(record.kind)+"-"+clip+".png")
		if not candidate_path.is_empty():
			for group in [3,4,7]:
				visual.dead=false
				check(avatar.receive_native_action({"protocol":"classic","action":group,"frame_count":16 if group==3 else 20 if group==4 else 5,"repeat_count":1,"delay":0}),"Avatar consumes the native dolphin category packet")
				check(visual.current_clip==({3:"Jump",4:"Roll",7:"Hit"}[group]) and not visual.dead,"Breach and hurt remain living actions through the actual presenter")
		var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(40.,.1,40.);collider.shape=shape;ground.add_child(collider);viewport.add_child(ground)
		avatar.set_physics_process(true);visual.set_physics_process(true);visual.dead=false;visual.action_remaining=0.;visual.current_clip="";var original_basis: Basis=visual.model.basis
		for level in [-5.,-.18,.21,.4]:
			for moving in [false,true]:
				ground.position.y=level-.05;ground.rotation.x=.1
				for frame in 35:await physics_frame;avatar.animate(moving,.7,1./60.,1.8);await process_frame
				check(is_zero_approx(avatar.ground_offset) and is_zero_approx(avatar.visual_root.position.y),"Seabed, land and decks cannot attract aquatic waterline")
				check(visual.contact.contacts.is_empty() and visual.model.basis.is_equal_approx(original_basis),"No land-ray tilt or tentacle pinning")
				check(avatar.global_position.is_zero_approx(),"Native entity position remains authoritative")
				check(visual.current_clip==("Walk" if moving else "Idle"),"Source swimming gait follows native movement state")
		avatar.set_physics_process(false);visual.set_physics_process(false);ground.free();avatar.free()
		var posed:=Corpses.posed(body,53);var frozen:=Corpses.freeze(posed)
		check(frozen!=null and frozen.get_meta("corpse_body")==body and frozen.get_meta("static_cadaver"),"Matching native-body static cadaver is available")
		check(frozen.find_children("*","Skeleton3D",true,false).is_empty(),"Static sea cadaver has no live skeleton")
		posed.free();if frozen:frozen.free()
	for name in FILES:check(runtime[name]==FileAccess.get_sha256("res://Presentation/"+name),"Runtime input unchanged: "+name)
	check(preparation_sha==FileAccess.get_sha256(path),"Preparation remains unchanged during rendering")
	var result:={"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"assets":assets,"runtime_sha256":runtime,"preparation_sha256":preparation_sha,"samples":samples,"scope":"Actual wet/alpha material, preserved native surface anchor against finite seabed/deck/land colliders, gait and frozen cadaver. Not original-client waterline or native aquatic movement proof."}
	var file:=FileAccess.open(output+"/validation.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print("AQUATIC PRESENTATION / ",family,": ",checks," checks / ",failures," failures");quit(1 if failures else 0)
