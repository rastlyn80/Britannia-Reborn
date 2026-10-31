extends SceneTree
## Builds the ignored graphics-ID/body catalogue and checks every supported cadaver.
const Corpses=preload("res://Presentation/CorpseModels.gd")
const SkinBounds=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func bounds(actor: Node3D) -> AABB:
	var first:=true;var result:=AABB()
	for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree() or mesh.mesh==null or mesh.has_meta("source_death_flash"):continue
		var box: AABB
		if mesh.skin:box=SkinBounds.deformed_bounds(mesh,mesh.get_node(mesh.skeleton))
		else:
			var vertex_first:=true
			for surface in mesh.mesh.get_surface_count():
				for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
					var position:=mesh.global_transform*point
					box=AABB(position,Vector3.ZERO) if vertex_first else box.expand(position);vertex_first=false
		result=box if first else result.merge(box);first=false
	return result
func run() -> void:
	var render: bool="--render" in OS.get_cmdline_user_args()
	var index_only: bool="--index-only" in OS.get_cmdline_user_args()
	var destination:=ProjectSettings.globalize_path("res://../outputs/corpses")
	var candidate:="";var candidate_bodies: Array[int]=[]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--candidate="):candidate=arg.trim_prefix("--candidate=")
	if not candidate.is_empty():
		if not candidate.is_valid_identifier():push_error("Invalid corpse candidate family");quit(1);return
		var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/"+candidate+"/preparation.json"))
		Corpses.Creatures.load_index()
		for row: Dictionary in preparation.get("models",[]):
			if row.get("status","")!="prepared":continue
			for identity: Dictionary in row.get("bodies",[]):
				Corpses.Creatures.entries[int(identity.body)]=row;candidate_bodies.append(int(identity.body))
		destination=ProjectSettings.globalize_path("res://../outputs/creatures/"+candidate+"/corpses")
	DirAccess.make_dir_recursive_absolute(destination.path_join("art"))
	if render:
		viewport=SubViewport.new();viewport.size=Vector2i(480,360);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
		preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
		stage=Node3D.new();viewport.add_child(stage)
		camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;viewport.add_child(camera)
	var records:=Corpses.catalogue()
	if not candidate.is_empty():records.assign(records.filter(func(row: Dictionary):return int(row.body) in candidate_bodies))
	check(not records.is_empty(),"Supported body catalogue is not empty")
	check(Corpses.build(0x7fff)==null,"Unsupported body does not acquire invented corpse art")
	for record: Dictionary in records:
		if index_only:continue
		var body:=int(record.body);var hue:=1002 if body in [400,401] else 0
		var actor:=Corpses.posed(body,hue)
		check(actor!=null,"Death pose exists for "+str(record.name))
		if actor==null:continue
		var expected:=bounds(actor);var frozen:=Corpses.freeze(actor)
		check(frozen!=null,"Finite frozen cadaver for "+str(record.name))
		if frozen==null:actor.free();continue
		var box: AABB=frozen.get_meta("corpse_bounds")
		check(box.size.distance_to(expected.size)<.0002,"CPU baked cadaver matches final skinned death bounds within 0.2 mm for %s: %s vs %s"%[body,box.size,expected.size])
		check(is_zero_approx(box.position.y),"Static cadaver rests on the floor for "+str(body))
		check(frozen.find_children("*","Skeleton3D",true,false).is_empty() and frozen.find_children("*","AnimationPlayer",true,false).is_empty(),"Cadaver needs no skeleton or animation processing")
		check(int(frozen.get_meta("corpse_body"))==body and int(frozen.get_meta("native_hue"))==hue,"Frozen body and raw hue remain intact")
		for mesh: MeshInstance3D in frozen.get_children():
			for surface in mesh.mesh.get_surface_count():
				var arrays:=mesh.mesh.surface_get_arrays(surface)
				check(arrays[Mesh.ARRAY_BONES]==null and arrays[Mesh.ARRAY_WEIGHTS]==null,"Static mesh contains no live skin bindings")
		record["vertices"]=frozen.get_meta("vertices");record["death_clip"]=frozen.get_meta("death_clip");record["preview_hue"]=hue
		record["asset"]=actor.model.scene_file_path;record["asset_sha256"]=FileAccess.get_sha256(actor.model.scene_file_path)
		record["bounds"]={"position":[box.position.x,box.position.y,box.position.z],"size":[box.size.x,box.size.y,box.size.z]}
		actor.free()
		if render:
			stage.add_child(frozen)
			var center:=box.get_center();camera.size=maxf(box.size.length()*1.15,.5);camera.position=center+Vector3(2.,2.6,3.).normalized()*maxf(box.size.length()*3.,4.);camera.look_at(center)
			for frame in 2:await process_frame
			await RenderingServer.frame_post_draw
			var image:=viewport.get_texture().get_image()
			check(image!=null and not image.is_empty(),"Actual corpse preview renders")
			if image:check(image.save_png(destination.path_join("art/"+str(record.key)+".png"))==OK,"Preview saved")
			record["preview"]="art/"+str(record.key)+".png"
		frozen.free()
		print("CORPSE: ",record.body_hex," / ",record.name)
		await process_frame
	# An accepted future body participates without a manually maintained list.
	var registry:=preload("res://Presentation/CreatureRegistry.gd")
	if not registry.entries.is_empty():
		registry.entries[0x7ffe]=registry.entries.values()[0]
		check(Corpses.catalogue().any(func(row: Dictionary):return int(row.body)==0x7ffe),"Future accepted bodies automatically join corpse graphics")
		registry.entries.erase(0x7ffe)
	var report:={"graphic":Corpses.GRAPHIC,"graphic_hex":"0x2006","selector":"amount = native body ID; hue and direction remain native item properties","entries":records,"checks":checks,"failures":failures,"rendered":render,"runtime_sha256":{"CorpseModels.gd":FileAccess.get_sha256("res://Presentation/CorpseModels.gd")},"scope":"Static meshes frozen at final Death. All available accepted human/mount/animal/creature bodies, plus labelled client compatibility artwork. Entries do not grant native corpse creation to creatures whose server suppresses it. No death FX in resting cadavers."}
	var output:=FileAccess.open(destination.path_join("catalogue.json"),FileAccess.WRITE);output.store_string(JSON.stringify(report,"\t"));output.close()
	output=FileAccess.open(destination.path_join("catalogue.js"),FileAccess.WRITE);output.store_string("window.CORPSES="+JSON.stringify(report)+";");output.close()
	print("CORPSE CATALOGUE: ",records.size()," bodies / ",checks," checks / ",failures," failures");quit(1 if failures else 0)
