extends SceneTree
## Actual modern avatars with in-memory candidate profiles; no accepted index edits.
const Profiles=preload("res://Presentation/HumanNPCProfiles.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Corpses=preload("res://Presentation/CorpseModels.gd")
const Paint=preload("res://Presentation/SavageBodyPaint.gd")
const INPUTS=["HumanNPCProfiles.gd","SavageHumanProfileTests.gd","SavagePaintAttributeTests.gd","SavageBodyPaint.gd","SavageSkin.gdshader","HumanAvatar.gd","HumanWardrobe.gd","HumanVisual.gd","HumanActions.gd","CorpseModels.gd","HumanHue.gd","HumanMotion.gd"]
var checks:=0
var failures:=0
var viewport: SubViewport
var camera: Camera3D
var rows: Array=[]
func _initialize() -> void:
	create_timer(180.).timeout.connect(func():push_error("Savage profile test deadline");quit(1))
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func capture() -> Image:
	await process_frame;await process_frame
	RenderingServer.force_draw(false)
	var result:=viewport.get_texture().get_image();result.convert(Image.FORMAT_RGBA8);return result
func changed(a: Image,b: Image) -> int:
	var count:=0
	for y in range(0,a.get_height(),3):
		for x in range(0,a.get_width(),3):
			var p:=a.get_pixel(x,y);var q:=b.get_pixel(x,y)
			if Vector3(p.r,p.g,p.b).distance_to(Vector3(q.r,q.g,q.b))>.08:count+=1
	return count
func skin_arrays(human: Node3D,painted: bool) -> void:
	var found:=0
	for mesh: MeshInstance3D in human.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override!=human.skin or not mesh.is_visible_in_tree():continue
		found+=1
		if not painted:
			check(mesh.mesh==mesh.get_meta("unpainted_mesh",mesh.mesh),"Returning to ordinary human restores original skin mesh")
			continue
		check(mesh.has_meta("unpainted_mesh"),"Visible original and masked body parts have rest-coordinate sources")
		if not mesh.has_meta("unpainted_mesh"):continue
		var source: ArrayMesh=mesh.get_meta("unpainted_mesh")
		for surface in source.get_surface_count():
			var before:=source.surface_get_arrays(surface);var after:=mesh.mesh.surface_get_arrays(surface)
			for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_INDEX]:check(before[channel]==after[channel],"Paint retains actual modern body channel %d"%channel)
			check(RenderingServer.mesh_get_surface(source.get_rid(),surface).lods==RenderingServer.mesh_get_surface(mesh.mesh.get_rid(),surface).lods,"Actual imported distance-detail meshes are unchanged")
			var points: PackedVector3Array=before[Mesh.ARRAY_VERTEX];var coords: PackedFloat32Array=after[Mesh.ARRAY_CUSTOM0];var worst:=0.
			var scale:=1.8/(1.72 if human.female else 1.8)
			for i in points.size():worst=maxf(worst,Vector3(coords[i*3],coords[i*3+1],coords[i*3+2]).distance_to(points[i]*scale))
			check(worst<.000001,"Every actual rest coordinate remains attached within one micrometre")
	check(found>0,"Actual visible human skin participates in profile")
func run() -> void:
	var runtime_start: Dictionary={}
	for name in INPUTS:runtime_start[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var preparation_path:="res://local-art/human-npcs/savages/preparation.json"
	var preparation_sha:=FileAccess.get_sha256(preparation_path)
	var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(preparation_path))
	var pins_path:="res://../scripts/savage-profile-inputs.json";var pins_sha:=FileAccess.get_sha256(pins_path)
	var pins: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(pins_path))
	Profiles.load_index();var original:=Profiles.entries.duplicate(true)
	Profiles.entries={}
	for body in [183,184,185,186]:check(not Profiles.supports_body(body),"Unaccepted Savage body stays outside active routes")
	for profile: Dictionary in preparation.profiles:
		check(profile.status=="prepared" and int(profile.body) in [183,184],"Only prepared foot candidates enter private test")
		Profiles.entries[int(profile.body)]=profile
	viewport=SubViewport.new();viewport.size=Vector2i(720,900);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.25;camera.position=Vector3(.8,1.,4.);viewport.add_child(camera);camera.look_at(Vector3(0.,.95,0.))
	for body in [183,184]:
		var actor:=Avatar.new();actor.initial_body=body;viewport.add_child(actor);actor.set_process(false);actor.set_physics_process(false)
		var human: Node3D=actor.human_visual
		check(human!=null and actor.horse_visual==null and human.female==(body==184),"Native body selects correct modern human gender, never monster renderer")
		if human==null:continue
		human.set_process(false)
		var entity:={"serial":123,"body":body,"hue":0,"flags":0,"notoriety":3,"x":0,"y":0,"z":0,"direction":0}
		actor.apply_server_appearance(entity,[]);human.animator.play("Idle",0.);human.animator.seek(.3,true);human.animator.pause()
		var painted:=await capture();skin_arrays(human,true)
		check(actor.native_body==body and actor.server_appearance.body==body and human.native_body_profile.body==body,"Native body identity survives presentation substitution")
		for group in range(35):
			if group in [23,24,25,26,27,28,29]:continue
			human.cancel_action()
			check(actor.receive_native_action({"body":body,"protocol":"classic","action":group,"frames":5,"repeat_count":1,"reverse":false,"repeat":false,"delay":0}),"Accepted human-type candidate receives classic action %d"%group)
			human.animator.advance(.12)
			check(not human.action_clip.is_empty(),"Action selects actual installed modern clip")
		human.cancel_action()
		var worn: Array=[{"id":0x144e,"layer":19,"hue":0},{"id":0x1452,"layer":4,"hue":0},{"id":0x0f62,"layer":2,"hue":0}]
		actor.apply_server_appearance(entity,worn);skin_arrays(human,true)
		check(human.unsupported_items.is_empty() and human.missing_art.is_empty(),"Existing native spear and bone arm/leg categories resolve on both genders")
		human.animator.play("Idle",0.);human.animator.seek(.3,true);human.animator.pause()
		var equipped:=await capture();check(changed(painted,equipped)>150,"Actual native equipment changes the rendered avatar")
		equipped.save_png("res://../work/creatures/savages/profile-%d-equipped.png"%body)
		var cosmetics:=worn.duplicate(true);cosmetics.append({"id":0x203c,"layer":11,"hue":53})
		if body==183:cosmetics.append({"id":0x2040,"layer":16,"hue":54})
		var details:=preload("res://Network/MobileAppearance.gd").profile(entity,cosmetics,{"hits":87,"strength":101},"Native Savage")
		actor.apply_server_appearance(entity,cosmetics,details);skin_arrays(human,true)
		check(actor.server_appearance.hair_id==0x203c and actor.server_appearance.hair_hue==53 and actor.server_appearance.statistics=={"hits":87,"strength":101},"Native hair hue/type and supplied statistics survive human NPC profile")
		if body==183:check(actor.server_appearance.beard_id==0x2040 and actor.server_appearance.beard_hue==54,"Native male beard type/colour survive body paint and clothing rebuild")
		actor.apply_server_appearance(entity,worn)
		for hue in [53,0x8035]:
			entity.hue=hue;actor.apply_server_appearance(entity,worn)
			check(human.skin_hue==hue and human.skin.get_shader_parameter("use_hue") and human.skin.get_shader_parameter("partial_hue")==((hue&0x8000)!=0),"Exact full/partial native hue flags reach paint material")
			check(changed(equipped,await capture())>20,"Native paint hue produces actual visible colour change")
		entity.hue=0;actor.apply_server_appearance(entity,worn)
		var corpse:=Corpses.build(body,53,worn)
		check(corpse!=null,"Native Savage body builds matching equipped static cadaver")
		if corpse!=null:
			check(corpse.get_meta("corpse_body")==body and corpse.get_meta("graphic_id")==0x2006 and corpse.get_meta("native_hue")==53,"Corpse retains native body/graphic/hue")
			check(corpse.find_children("*","Skeleton3D",true,false).is_empty(),"Static Savage cadaver has no processing rig")
			actor.visible=false;viewport.add_child(corpse)
			var first:=await capture();var later:=await capture()
			check(changed(first,later)==0,"Frozen paint remains visually stable between rendered frames")
			first.save_png("res://../work/creatures/savages/profile-%d-corpse.png"%body)
			corpse.free();actor.visible=true
		entity.body=401 if body==184 else 400;entity.hue=1002;actor.apply_server_appearance(entity,[]);skin_arrays(human,false)
		human.animator.play("Idle",0.);human.animator.seek(.3,true);human.animator.pause()
		check(human.native_body_profile.is_empty() and human.skin.shader!=human.skin.get_meta("savage_shader"),"Native transformation back to ordinary human removes paint shader/profile")
		check(changed(painted,await capture())>100,"Restored natural skin is visibly distinct from painted body")
		rows.append({"body":body,"gender":"female" if body==184 else "male","classic_foot_groups":28,"native_server_tested":false})
		actor.free()
	Profiles.entries=original
	for body in [183,184]:check(Profiles.supports_body(body)==original.has(body),"Temporary candidate test restores previous accepted routing")
	for name in INPUTS:check(runtime_start[name]==FileAccess.get_sha256("res://Presentation/"+name),"Runtime/test inputs remain unchanged during actual render sampling")
	check(preparation_sha==FileAccess.get_sha256(preparation_path) and pins_sha==FileAccess.get_sha256(pins_path),"Exact preparation/input manifest remains unchanged during sampling")
	for path: String in pins.prepared_art:check(FileAccess.get_sha256("res://../"+path)==pins.prepared_art[path],"Prepared art/import remains identical to the pinned input")
	var report:={"checks":checks,"failures":failures,"profiles":rows,"runtime_sha256":runtime_start,"preparation_sha256":preparation_sha,"input_manifest_sha256":pins_sha,"scope":"Actual modern avatars and GPU paint/equipment/hues/static corpses; in-memory prepared candidates only. No native constructor/gameplay, masks, dance, ridgeback, terrain acceptance or added coverage."}
	var file:=FileAccess.open("res://../work/creatures/savages/profile-tests.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SAVAGE HUMAN PROFILES: ",checks," checks / ",failures," failures; no route acceptance");quit(1 if failures else 0)
