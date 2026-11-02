extends SceneTree
## Timed candidate transitions, real finite support planes, independent skins.
const Visual=preload("res://Presentation/SourceSolenWarriorVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(600.).timeout.connect(func():push_error("SolenWarrior finite terrain deadline");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		if failures<12:push_error(label)
func gap(mesh: MeshInstance3D,rig: Skeleton3D,space: Transform3D,origin: Vector3,normal: Vector3,subset: PackedInt32Array=PackedInt32Array()) -> float:
	var transforms: Array[Transform3D]=[]
	for bind in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(bind)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
		transforms.append(space*rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
	var minimum:=INF
	for surface in mesh.mesh.get_surface_count():
		var a:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var bones: PackedInt32Array=a[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var stride: int=bones.size()/vertices.size()
		var selected: PackedInt32Array=subset
		if selected.is_empty():
			for index in vertices.size():selected.append(index)
		for vertex in selected:
			var point:=Vector3.ZERO
			for slot in stride:
				var offset:=vertex*stride+slot;point+=(transforms[bones[offset]]*vertices[vertex])*weights[offset]
			minimum=minf(minimum,normal.dot(point-origin))
	return minimum
func foot_vertices(mesh: MeshInstance3D,rig: Skeleton3D,end: int) -> PackedInt32Array:
	var a:=mesh.mesh.surface_get_arrays(0);var indices: PackedInt32Array=a[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var points: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var result:=PackedInt32Array();var stride: int=indices.size()/points.size()
	for vertex in points.size():
		var total:=0.
		for slot in stride:
			var offset:=vertex*stride+slot;var bone:=mesh.skin.get_bind_bone(indices[offset])
			if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(indices[offset]))
			while bone>=0:
				if bone==end:total+=weights[offset];break
				bone=rig.get_bone_parent(bone)
		if total>.6:result.append(vertex)
	return result
func run() -> void:
	var prep_path:="res://local-art/creatures/solen_warriors/preparation.json";var prep_pin:=FileAccess.get_sha256(prep_path)
	var ground_pins: Dictionary={}
	var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(prep_path))
	for row: Dictionary in prep.models:ground_pins[str(row.ground_lookup)]=FileAccess.get_sha256(str(row.ground_lookup))
	var runtime: Dictionary={}
	for name in ["SolenWarriorTerrainTests.gd","SourceSolenWarriorVisual.gd","SourceSolenWarriorSupport.gd","SourceSolenVisual.gd","SourceSolenSupport.gd","SourceSolenMaterial.gd","SourceSolenSurface.gdshader","SmallSnakeVisual.gd","MeasuredCreatureSupport.gd","CreatureVisual.gd","SourceMountContact.gd","SourceGroundLookup.gd","SkinGeometry.gd","OstardVisual.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var records: Array=[];var misses: Array=[];var total_poses:=0;var max_skin:=0.;var max_foot:=0.
	for entry: Dictionary in prep.models:
		for plane: Dictionary in [{"name":"flat","height":0.,"tilt":Vector3.ZERO},{"name":"forward","height":.25,"tilt":Vector3(.16,0.,0.)},{"name":"cross","height":-.15,"tilt":Vector3(0.,0.,-.14)}]:
			var basis:=Basis.from_euler(plane.tilt);var normal:=basis.y;var origin:=Vector3(11.,plane.height,-7.)
			var platform:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(6.,.1,6.);shape.shape=box;platform.add_child(shape);root.add_child(platform);platform.global_transform=Transform3D(basis,origin-normal*.05)
			await physics_frame;await physics_frame
			for config: Dictionary in [{"rate":.65,"fps":30,"phase":.31},{"rate":1.65,"fps":90,"phase":.74}]:
				var rate:=float(config.rate)
				for fps: int in [int(config.fps)]:
					for pair: Array in [["Idle","Walk"],["Walk","Run"],["Run","Walk"],["Run","Attack"],["Run","Attack2"],["Run","Attack3"],["Run","Fidget2"],["Run","Death"]]:
						for phase: float in [float(config.phase)]:
							var visual:=Visual.new();visual.entry=entry;root.add_child(visual);visual.position=origin;visual.set_process(false);visual.set_physics_process(false);visual.contact.active=false;visual.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
							var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0];var rig: Skeleton3D=visual.skeleton;var foot_sets: Array=[];var leg_joints: Dictionary={}
							for foot: Dictionary in visual.contact.feet:
								foot_sets.append(foot_vertices(mesh,rig,int(foot.end)))
								for key: String in ["a","b","c"]:leg_joints[int(foot[key])]=true
							check(foot_sets.size()==6 and foot_sets.all(func(v):return not v.is_empty()),"All six source feet have independently classified weighted skin")
							visual.play(str(pair[0]),0.);visual.animator.seek(visual.animator.get_animation(str(pair[0])).length*phase,true)
							for warm in 40:
								visual.animator.advance(0.);visual._physics_process(1./60.);visual.contact._process_modification_with_delta(1./60.);rig.force_update_all_bone_transforms()
							visual.dead=str(pair[1])=="Death";visual.contact.enabled=not visual.dead;visual.animator.speed_scale=rate;visual.play(str(pair[1]),.18)
							var skin_error:=0.;var foot_error:=0.;var steps:=ceili(.5*fps)
							for step in steps:
								var dt:=1./fps;visual._process(dt);visual.animator.advance(dt);visual._physics_process(dt);rig.force_update_all_bone_transforms()
								var positions: Array[Vector3]=[];var bases: Array[Basis]=[]
								for bone in rig.get_bone_count():positions.append(rig.get_bone_pose_position(bone));bases.append(rig.get_bone_pose(bone).basis)
								var flat:=Transform3D(visual.contact.flat_basis,Vector3.ZERO)*visual.model.global_transform.affine_inverse()*rig.global_transform;var expected_lifts: Array[float]=[];var expected_body:=maxf(0.,gap(mesh,rig,flat,Vector3.ZERO,Vector3.UP)+visual.contact.residual_height)
								for set: PackedInt32Array in foot_sets:expected_lifts.append(maxf(0.,gap(mesh,rig,flat,Vector3.ZERO,Vector3.UP,set)+visual.contact.residual_height))
								if not visual.dead:check(visual.contact.contacts.size()==6,"Living source soles raycast the actual finite plane")
								visual.contact._process_modification_with_delta(dt);rig.force_update_all_bone_transforms();visual.update_landmarks()
								var body_gap:=gap(mesh,rig,rig.global_transform,origin,normal);var body_error:=absf(body_gap-expected_body);skin_error=maxf(skin_error,body_error);max_skin=maxf(max_skin,body_error);total_poses+=1
								check(body_gap>-.008 and body_error<.008,"Complete timed skin retains independent source grounded/airborne clearance within8mm")
								var local_error:=0.
								if not visual.dead:
									for foot in foot_sets.size():
										var sole_gap:=gap(mesh,rig,rig.global_transform,origin,normal,foot_sets[foot]);var wanted:=expected_lifts[foot] if expected_lifts[foot]>=.002 else 0.
										local_error=maxf(local_error,absf(sole_gap-wanted))
									check(local_error<.008,"Independent actual soles retain source swing lift or planted contact within8mm")
								foot_error=maxf(foot_error,local_error);max_foot=maxf(max_foot,local_error)
								for bone in rig.get_bone_count():
									check(rig.get_bone_pose_position(bone).distance_to(positions[bone])<.00001,"Terrain IK leaves every source local translation/segment length intact")
									if not leg_joints.has(bone):check(rig.get_bone_pose(bone).basis.is_equal_approx(bases[bone]),"Terrain IK preserves every non-leg source joint basis")
								check(visual.position==origin and visual.model.position.x==0. and visual.model.position.z==0.,"Physical support leaves native coordinates/horizontal placement intact")
								var bounds:=Geometry.deformed_bounds(mesh,rig);check((visual.global_transform*(visual.get_meta("pick_bounds") as AABB)).grow(.001).encloses(bounds),"Complete mixed/slope skin stays inside actual picking metadata")
								if body_gap<=-.008 or body_error>=.008 or local_error>=.008:misses.append({"kind":entry.kind,"plane":plane.name,"pair":pair,"phase":phase,"rate":rate,"fps":fps,"step":step,"body_gap_m":body_gap,"expected_source_clearance_m":expected_body,"foot_error_m":local_error})
							records.append({"kind":entry.kind,"plane":plane.name,"pair":pair,"phase":phase,"rate":rate,"fps":fps,"poses":steps,"maximum_body_gap_m":skin_error,"maximum_foot_error_m":foot_error})
							visual.free();await process_frame
			var probe:=Visual.new();probe.entry=entry;root.add_child(probe);probe.position=origin;probe.set_process(false);probe.set_physics_process(false);probe.contact.active=false
			probe.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;probe.play("Idle",0.);probe.animator.seek(.173,true);probe.animator.advance(0.);probe._physics_process(.016)
			check(probe.contact.contacts.size()==6,"Finite platform still supplies all six real contacts at its centre")
			probe.position=origin+Vector3.RIGHT*8.;probe._physics_process(.016)
			check(probe.contact.contacts.is_empty(),"Moving beyond finite platform edges clears real contacts instead of extending a plane")
			probe.free();platform.free();await physics_frame
	for name: String in runtime:check(runtime[name]==FileAccess.get_sha256("res://Presentation/"+name),"Source input unchanged:"+name)
	check(prep_pin==FileAccess.get_sha256(prep_path),"Prepared data remains unchanged through real terrain tests")
	for path: String in ground_pins:check(ground_pins[path]==FileAccess.get_sha256(path),"Exact source curves remain unchanged")
	var report:={"checks":checks,"failures":failures,"poses":total_poses,"cases":records,"misses":misses,"maximum_skin_error_m":max_skin,"maximum_foot_error_m":max_foot,"runtime_sha256":runtime,"preparation_sha256":prep_pin,"ground_measurement_sha256":ground_pins,"scope":"Headless candidate SolenWarrior transitions on three real finite collision planes, two declared rate/fps/phase combinations, independent complete split vertices and independently classified feet; source translations/non-leg bases/native roots/picking metadata. Settled support before transitions. No GPU/native server/material/mixed ledge/spawn-settling or family acceptance."}
	FileAccess.open("res://../work/creatures/solen-warriors/terrain-tests.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("SOLEN WARRIOR TERRAIN: ",checks," checks / ",failures," failures / ",total_poses," poses");quit(1 if failures else 0)
