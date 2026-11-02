extends "res://Presentation/JukaPresentationTests.gd"
var wanted:=false
var sample_serial:=0
var sampled: Dictionary={}
func _initialize() -> void:
	create_timer(480.).timeout.connect(func():push_error("Juka mixed-terrain deadline");quit(1));call_deferred("run")
func minimum_gap(mesh: MeshInstance3D,rig: Skeleton3D,origin: Vector3,normal: Vector3,reference: Transform3D=Transform3D.IDENTITY) -> float:
	var matrices: Array[Transform3D]=[]
	for bind in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(bind)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
		matrices.append(rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
	var result:=INF
	for surface in mesh.mesh.get_surface_count():
		var arrays:=mesh.mesh.surface_get_arrays(surface);var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
		for vertex in points.size():
			var point:=Vector3.ZERO
			for slot in 4:point+=(matrices[bones[vertex*4+slot]]*points[vertex])*weights[vertex*4+slot]
			result=minf(result,normal.dot(reference*rig.to_global(point)-origin))
	return result
func run() -> void:
	var runtime_start: Dictionary={}
	for filename in INPUTS+["SourceGroundLookup.gd","JukaMixedTerrainTests.gd"]:runtime_start[filename]=FileAccess.get_sha256("res://Presentation/"+filename)
	var preparation:="res://local-art/creatures/juka/preparation.json";var preparation_start:=FileAccess.get_sha256(preparation);var assets: Dictionary={}
	var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/juka/preparation.json"));var rows: Array=[]
	viewport=SubViewport.new();viewport.size=Vector2i(650,650);viewport.own_world_3d=true;viewport.transparent_bg=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);preload("res://Presentation/ItemStudio.gd").studio_lights(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=7.;viewport.add_child(camera);camera.position=Vector3(3.,3.,5.);camera.look_at(Vector3(0.,1.,0.))
	var ground:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(12.,.1,12.);shape.shape=box;shape.position.y=-.05;ground.add_child(shape);viewport.add_child(ground)
	Registry.load_index()
	for record: Dictionary in prep.models:
		var body:=int(record.bodies[0].body);Registry.entries[body]=record
		var path:="res://local-art/creatures/"+str(record.kind)+"-modern.gltf";assets[record.kind]={"path":path,"asset_sha256":FileAccess.get_sha256(path),"import_sha256":FileAccess.get_sha256(path+".import")}
		var actor:=Avatar.new();actor.initial_body=body;var plate:=Label3D.new();plate.name="Nameplate";plate.text=str(record.kind).replace("_"," ");actor.add_child(plate);var picker:=StaticBody3D.new();picker.set_meta("server_mobile",true);picker.collision_layer=4;picker.collision_mask=0;var pick_shape:=CollisionShape3D.new();pick_shape.shape=BoxShape3D.new();picker.add_child(pick_shape);actor.add_child(picker);viewport.add_child(actor);actor.apply_server_appearance({"body":body,"hue":0},[])
		var visual: Node3D=actor.horse_visual;visual.set_process(false);var rig: Skeleton3D=visual.skeleton;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0];visual.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var expected: Dictionary={}
		visual.contact.modification_processed.connect(func():
			if not wanted:return
			wanted=false;sample_serial+=1
			var normal:=ground.global_basis.y.normalized();var origin:=ground.global_position;var foot_gaps: Array=[]
			for foot: Dictionary in visual.contact.feet:foot_gaps.append(normal.dot(visual.contact.sole(foot)-origin))
			var bounds:=Geometry.deformed_bounds(mesh,rig)
			sampled={"minimum_gap":minimum_gap(mesh,rig,origin,normal),"foot_gaps":foot_gaps,"lengths":lengths(rig,visual.contact.feet),"picker_contains":(pick_shape.global_transform*AABB(-(pick_shape.shape as BoxShape3D).size*.5,(pick_shape.shape as BoxShape3D).size)).grow(.01).encloses(bounds),"nameplate_clears":plate.global_position.y>bounds.end.y+.015}
		)
		for slope: Vector2 in [Vector2.ZERO,Vector2(.08,0.),Vector2(0.,-.08)]:
			for yaw: float in [0.,PI/2.]:
				ground.position.y=-.15 if yaw==0. else .18;ground.rotation=Vector3(slope.x,0.,slope.y)
				visual.dead=false;visual.contact.enabled=true;visual.current_clip="Idle";visual.action_remaining=1000.;visual.play("Idle",0.)
				for warm in 25:
					await physics_frame;actor.animate(false,yaw,1./60.,0.);visual.animator.seek(.2,true);visual.animator.advance(0.);await process_frame
				for pair: Array in [["Walk","Run"],["Run","AttackBow"],["Run","Cast"],["Run","Cast2"],["Run","Pillage"],["Run","Death"],["Run","Death2"]]:
					for rate: float in [.65,1.65]:
						visual.dead=false;visual.contact.enabled=true;visual.action_remaining=1000.;visual.current_clip=str(pair[0]);visual.animator.stop();visual.animator.speed_scale=rate;visual.play(pair[0],0.);visual.animator.seek(visual.animator.get_animation(pair[0]).length*.371,true);visual.animator.advance(0.);visual.current_clip=str(pair[1]);visual.dead=str(pair[1]).begins_with("Death");visual.contact.enabled=not visual.dead;visual.play(pair[1],.18)
						for frame in 24:
							await physics_frame;actor.animate(false,yaw,1./60.,0.);visual._process(1./60.);visual.animator.advance(1./60.);rig.force_update_all_bone_transforms();expected={"lifts":visual.contact.source_lifts(),"lengths":lengths(rig,visual.contact.feet),"source_airborne_height_m":0.}
							# Independently skin every vertex in the flat source frame before
							# the modifier runs; a real two-foot airborne pose must keep its lift.
							if not visual.dead and float(expected.lifts[0])>=.015 and float(expected.lifts[1])>=.015:
								var raw:=minimum_gap(mesh,rig,Vector3.ZERO,Vector3.UP,Transform3D(visual.contact.flat_basis,Vector3.ZERO)*visual.model.global_transform.affine_inverse());expected.raw_source_minimum=raw
								if raw>=.015:expected.source_airborne_height_m=raw
							var prior:=sample_serial;wanted=true
							await process_frame;await RenderingServer.frame_post_draw
							check(sample_serial>prior,"Actual render-stage source Juka modifier supplied a fresh mixed skin")
							if sample_serial==prior:continue
							check(absf(float(sampled.minimum_gap)-float(expected.source_airborne_height_m))<.008,"Complete rendered mixed Juka skin keeps measured source clearance within8mm of finite plane")
							check(sampled.picker_contains and sampled.nameplate_clears,"Actual mixed-pose picking collider/nameplate contains the complete modified skin")
							if not visual.dead:
								for i in visual.contact.feet.size():
									var target:=0. if float(expected.lifts[i])<.015 else float(expected.lifts[i]);check(absf(float(sampled.foot_gaps[i])-target)<.009,"Actual render-stage mixed foot keeps source lift above plane");check(absf(float(sampled.lengths[i][0])-float(expected.lengths[i][0]))<.001 and absf(float(sampled.lengths[i][1])-float(expected.lengths[i][1]))<.001,"Mixed support retains original source segment lengths")
							rows.append({"kind":record.kind,"pair":pair,"rate":rate,"slope":str(slope),"yaw":yaw,"frame":frame,"expected":expected.duplicate(true),"sample":sampled.duplicate(true)})
		actor.free()
	var runtime: Dictionary={}
	for filename in runtime_start:runtime[filename]=FileAccess.get_sha256("res://Presentation/"+filename)
	check(runtime==runtime_start,"Runtime/test inputs stayed unchanged throughout the rendered mixed-terrain proof")
	check(preparation_start==FileAccess.get_sha256(preparation),"Preparation stayed unchanged throughout the rendered mixed-terrain proof")
	for kind_name in assets:
		var pin: Dictionary=assets[kind_name];check(pin.asset_sha256==FileAccess.get_sha256(pin.path) and pin.import_sha256==FileAccess.get_sha256(str(pin.path)+".import"),"Saved asset/import stayed unchanged throughout the rendered mixed-terrain proof")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/creatures/juka"))
	FileAccess.open("res://../outputs/creatures/juka/mixed-terrain.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"runtime_sha256":runtime,"preparation_sha256":preparation_start,"assets":assets,"in_memory_routes_only":true,"renderer":RenderingServer.get_current_rendering_method(),"samples":rows,"scope":"Actual prepared avatar/render-stage modifiers/full weighted skins/picker/nameplate/source foot lifts and lengths over finite slope crossfades. Measured two-foot airborne source poses retain their independently skinned clearance. Coupled cloth/shoe contact uses bounded common minimax support; all original source limb segment lengths retained. No native socket or acceptance."}));print("SOURCE JUKA MIXED TERRAIN: ",checks," / ",failures," failures / ",rows.size()," rendered skins");quit(1 if failures else 0)
