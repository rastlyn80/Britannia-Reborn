extends SceneTree
const Visual=preload("res://Presentation/IceSerpentVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const PAIRS=[["Idle","Walk"],["Walk","Run"],["Run","Walk"],["Run","Attack"],["Attack","Idle"],["Hit","Walk"],["Fidget","Walk"],["Eat","Walk"]]
const RATES=[.25,.65,1.,6.8/5.5,3.2]
var checks:=0
var failures:=0
var visual: Node3D
var mesh: MeshInstance3D
var samples: Array=[]
var terrain: Array=[]
func _initialize() -> void:
	create_timer(180.).timeout.connect(func():push_error("Ice transition deadline exceeded");quit(1));call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<12:push_error(label)
func tick(delta: float,physics: bool=false) -> void:
	visual._process(delta)
	if physics:visual._physics_process(delta)
	visual.animator.advance(delta);visual.skeleton.force_update_all_bone_transforms()
func start(source: String,target: String,phase: float,blend: float=.18) -> void:
	visual.dead=false;visual.action_remaining=0.;visual.current_clip=source;visual.play(source,0.);visual.animator.seek(visual.animator.get_animation(source).length*phase,true);visual.animator.advance(0.);visual.play(target,blend)
func points() -> PackedVector3Array:
	# Independent full imported arrays; do not use the runtime's deduplicated set.
	var rig: Skeleton3D=visual.skeleton;var matrices: Array[Transform3D]=[]
	for i in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(i)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(i))
		matrices.append(rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(i))
	var result:=PackedVector3Array()
	for surface in mesh.mesh.get_surface_count():
		var a:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var bindings: PackedInt32Array=a[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var stride:=weights.size()/vertices.size()
		for vertex in vertices.size():
			var p:=Vector3.ZERO
			for slot in stride:p+=(matrices[bindings[vertex*stride+slot]]*vertices[vertex])*weights[vertex*stride+slot]
			result.append(rig.to_global(p))
	return result
func run() -> void:
	var path:="res://local-art/creatures/ice_serpents/preparation.json";var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path));var parent:=Node3D.new();root.add_child(parent);visual=Visual.new();visual.entry=prep.models[0];parent.add_child(visual);visual.set_process(false);visual.set_physics_process(false);visual.contact.enabled=false;visual.contact.active=false;visual.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;mesh=visual.model.find_children("*","MeshInstance3D",true,false)[0]
	check(int(visual.support_skin.unique_vertices)<int(visual.support_skin.source_vertices),"Runtime floor solver caches shared position/weight tuples across UV/normal seams")
	var source_vertices: int=visual.support_skin.source_vertices;var unique_vertices: int=visual.support_skin.unique_vertices
	for rate: float in RATES:
		visual.animator.speed_scale=rate
		for fps in [30,60]:
			var delta:=1./float(fps)
			for pair: Array in PAIRS:
				for phase in [.31,.74]:
					start(pair[0],pair[1],phase)
					for frame in ceili(1.05*fps):
						tick(delta);var box:=Geometry.deformed_bounds(mesh,visual.skeleton)
						check(box.position.is_finite() and box.size.is_finite() and absf(box.position.y)<.008,"Complete blended skin remains grounded at slow/native/fast rates and both frame steps")
						check((visual.global_transform*(visual.get_meta("pick_bounds") as AABB)).grow(.001).encloses(box),"Dynamic bounds follow every actual mixed pose")
						check(visual.position.is_zero_approx() and visual.model.position.x==0. and visual.model.position.z==0.,"Blend support changes only the visual's common vertical model offset")
						samples.append({"rate":rate,"fps":fps,"source":pair[0],"target":pair[1],"phase":phase,"elapsed":float(frame+1)*delta,"floor_m":box.position.y})
	var timings: Array=[]
	for preceding_rate in [.25,1.,3.2]:
		visual.animator.speed_scale=preceding_rate;visual.dead=false;visual.action_remaining=0.;visual.play("Run",0.);visual.animator.seek(.2,true);visual.animator.advance(0.)
		check(visual.receive_action({"protocol":"classic","action":4,"frames":5,"delay":0}),"Native monster attack request is accepted after every prior gait rate")
		var length: float=visual.animator.get_animation("Attack").length
		check(is_equal_approx(visual.animator.speed_scale,1.) and absf(visual.animator.get_playing_speed()-length/.8)<.0001,"Native packet's800ms duration is independent of previous movement cadence")
		tick(.4);var middle: float=visual.animator.current_animation_position;check(absf(middle-length*.5)<.001,"Actual native attack reaches half its authored track at half the requested duration")
		tick(.4);check(absf(float(visual.animator.current_animation_position)-length)<.001,"Actual native attack completes at the requested duration")
		timings.append({"preceding_rate":preceding_rate,"requested_seconds":.8,"authored_length":length,"midpoint_position":middle})
	var ground:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box_shape:=BoxShape3D.new();box_shape.size=Vector3(24.,.1,24.);shape.shape=box_shape;shape.position.y=-.05;ground.add_child(shape);root.add_child(ground);visual.contact.enabled=true
	for slope in [Vector2.ZERO,Vector2(.08,0.),Vector2(0.,-.08)]:
		for yaw in [0.,PI/2.]:
			var height: float=-.15 if yaw==0. else .18;ground.position.y=height;ground.rotation=Vector3(slope.x,0.,slope.y);parent.position.y=height;visual.rotation.y=yaw
			await physics_frame;await physics_frame
			for warm in 40:visual._physics_process(1./30.)
			check(visual.contact.contacts.has(0),"Actual raised/lowered sloped collider supplies a measured support plane")
			for rate in [.25,6.8/5.5]:
				visual.animator.speed_scale=rate
				for pair in [["Walk","Run"],["Run","Attack"],["Attack","Idle"]]:
					start(pair[0],pair[1],.371)
					for frame in 24:
						tick(1./60.,true);var hit: Dictionary=visual.contact.contacts[0];var lowest:=INF
						for p: Vector3 in points():lowest=minf(lowest,(hit.normal as Vector3).dot(p-(hit.position as Vector3)))
						check(absf(lowest)<.008,"Complete mixed skin remains within8mm of the real finite support plane")
						check(visual.position.is_zero_approx(),"Finite-plane blend correction preserves the actor's native local coordinates")
						terrain.append({"rate":rate,"source":pair[0],"target":pair[1],"yaw":yaw,"slope":str(slope),"elapsed":float(frame+1)/60.,"gap_m":lowest})
	ground.free();parent.position=Vector3.ZERO;visual.rotation=Vector3.ZERO;visual.contact.contacts.clear();visual.animator.speed_scale=1.;start("Walk","Run",.31);tick(.05);visual.blend_remaining=1.;var before:=Time.get_ticks_usec()
	for i in 100:visual.apply_ground()
	var average_us:=float(Time.get_ticks_usec()-before)/100.;check(average_us<10000.,"Measured temporary skin support remains below10ms per evaluation on this host")
	var runtime: Dictionary={}
	for name in ["IceSerpentTransitionTests.gd","IceSerpentVisual.gd","SourceGroundLookup.gd","SmallSnakeVisual.gd","CreatureVisual.gd","SkinGeometry.gd","HumanActions.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var asset:="res://local-art/creatures/serpents_snake_giant_ice-modern.gltf";var receipt:={"checks":checks,"failures":failures,"flat_samples":samples,"terrain_samples":terrain,"native_timing":timings,"source_vertices":source_vertices,"unique_vertices":unique_vertices,"temporary_support_mean_us":average_us,"runtime_sha256":runtime,"preparation_sha256":FileAccess.get_sha256(path),"asset_sha256":FileAccess.get_sha256(asset),"import_sha256":FileAccess.get_sha256(asset+".import"),"ground_lookup_sha256":FileAccess.get_sha256(str(visual.entry.ground_lookup)),"scope":"Actual mixed poses at five playback rates/two update steps, real six finite-plane collider configurations, independent complete skin sampling and actual native-action duration API. Offline controlled renderer test; native two-client receipt is separate. No arbitrary-terrain or whole-game performance certification."}
	parent.free();FileAccess.open("res://../outputs/creatures/ice_serpents/transitions.json",FileAccess.WRITE).store_string(JSON.stringify(receipt));print("ICE TRANSITIONS: ",checks," checks / ",failures," failures; ",samples.size()," mixed poses / ",terrain.size()," plane poses; ",unique_vertices," unique points, ",average_us,"us per temporary support sample");quit(1 if failures else 0)
