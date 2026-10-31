extends SceneTree
## Actual avatar support on measured collision planes; no network gameplay claim.
const Registry=preload("res://Presentation/CreatureRegistry.gd")
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
var family:="gazers"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--family="):family=arg.trim_prefix("--family=")
	assert(family in ["gazers","genies"])
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var preparation: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/"+family+"/preparation.json"))
	Registry.load_index()
	var ground:=StaticBody3D.new();var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(30.,.1,30.);collider.shape=shape;collider.position.y=-.05;ground.add_child(collider);root.add_child(ground)
	var records: Array=[];var assets: Dictionary={};var expected_cases:=0
	for row: Dictionary in preparation.models:
		if row.status!="prepared":continue
		expected_cases+=row.bodies.size()*6
		check(row.get("movement_mode","")=="source_hover","Floating source movement is declared explicitly")
		for identity: Dictionary in row.bodies:
			var body:=int(identity.body);Registry.entries[body]=row
			var avatar:=Avatar.new();avatar.initial_body=body;root.add_child(avatar)
			avatar.apply_server_appearance({"body":body,"hue":0x8035},[])
			var visual: Node3D=avatar.horse_visual
			check(visual!=null and visual.contact.feet.is_empty(),"Floating creature does not invent foot IK")
			var expected_scale: Vector3=visual.model.scale
			var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0]
			visual.play("Idle",0.);visual.animator.seek(visual.animator.current_animation_length*.3,true);visual.animator.pause()
			for level in [-.18,.21]:
				for slope in [Vector2.ZERO,Vector2(.08,0.),Vector2(0.,.06)]:
					ground.position.y=level;ground.rotation=Vector3(slope.x,0.,slope.y)
					for frame in 50:
						await physics_frame;avatar.animate(false,0.,1./60.,0.);await process_frame
					var hit:=root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.,2.,0.),Vector3(0.,-2.,0.),1))
					check(not hit.is_empty(),"Actual support collision is sampled")
					if hit.is_empty():continue
					var bounds:=Geometry.deformed_bounds(mesh,visual.skeleton);var normal: Vector3=hit.normal;var top: float=-INF
					for x in [bounds.position.x,bounds.end.x]:
						for z in [bounds.position.z,bounds.end.z]:top=maxf(top,hit.position.y-(normal.x*x+normal.z*z)/normal.y)
					var clearance:=bounds.position.y-top
					check(absf(avatar.ground_offset-hit.position.y)<.015,"Avatar follows rendered support within 15 mm")
					check(clearance>.12,"Actual floating skin clears the sampled slope by at least 120 mm")
					check(avatar.transform.is_equal_approx(Transform3D.IDENTITY),"Support correction never moves native entity coordinates")
					check(visual.model.scale.is_equal_approx(expected_scale) and visual.native_body==body and visual.native_hue==0x8035,"Hover support preserves native proportions, identity and raw hue")
					records.append({"kind":row.kind,"body":body,"plane_height":hit.position.y,"slope":str(slope),"visual_offset":avatar.ground_offset,"conservative_skin_clearance_m":clearance})
			avatar.free()
		var path:="res://local-art/creatures/"+str(row.kind)+"-modern.gltf"
		assets[row.kind]={"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import")}
	ground.free()
	check(records.size()==expected_cases and expected_cases>0,"Every floating body covers raised/lowered flat and sloped support")
	var runtime: Dictionary={}
	for name in ["FloatingCreatureTests.gd","HumanAvatar.gd","LegacyAvatar.gd","CreatureVisual.gd","SourceMountContact.gd","SkinGeometry.gd","FootContact.gd","MountVisual.gd","CreatureRegistry.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/creatures/"+family))
	var output:=FileAccess.open("res://../outputs/creatures/"+family+"/hover-contact.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records,"assets":assets,"runtime_sha256":runtime,"scope":"Actual avatar physics support, preserved source hover and conservative skinned clearance on six finite collision planes per body. Offline presentation; not arbitrary obstacles, full volume sweep or native AI gameplay."},"\t"));output.close()
	print("FLOATING CREATURE SUPPORT: ",checks-failures," / ",checks,"; ",records.size()," measured cases");quit(1 if failures else 0)
