extends SceneTree
const Visual=preload("res://Presentation/SourceJukaVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<12:push_error(label)
func source_minimum(visual: Node3D,mesh: MeshInstance3D) -> float:
	var rig: Skeleton3D=visual.skeleton;var matrices: Array[Transform3D]=[]
	for bind in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(bind)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
		matrices.append(rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(bind))
	var reference: Transform3D=Transform3D(visual.contact.flat_basis,Vector3.ZERO)*visual.model.global_transform.affine_inverse()*rig.global_transform
	var minimum:=INF
	for surface in mesh.mesh.get_surface_count():
		var arrays:=mesh.mesh.surface_get_arrays(surface);var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
		for vertex in points.size():
			var point:=Vector3.ZERO
			for slot in 4:point+=(matrices[bones[vertex*4+slot]]*points[vertex])*weights[vertex*4+slot]
			minimum=minf(minimum,(reference*point).y)
	return minimum
func run() -> void:
	var runtime: Dictionary={};var assets: Dictionary={};var preparation:="res://local-art/creatures/juka/preparation.json";var preparation_pin:=FileAccess.get_sha256(preparation)
	for name in ["JukaTransitionTests.gd","SourceJukaVisual.gd","SourceJukaSupport.gd","SourceMageVisual.gd","SourceMageSupport.gd","MeasuredCreatureVisual.gd","MeasuredCreatureSupport.gd","SourceBipedVisual.gd","SourceBipedSupport.gd","CreatureVisual.gd","OstardVisual.gd","SourceGroundLookup.gd","SkinGeometry.gd"]:runtime[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/juka/preparation.json"));var rows: Array=[];var maximum:=0.;var samples:=0;var airborne_cases:=0;var maximum_airborne:=0.
	for record: Dictionary in prep.models:
		var asset:="res://local-art/creatures/"+str(record.kind)+"-modern.gltf";assets[record.kind]={"path":asset,"asset_sha256":FileAccess.get_sha256(asset),"import_sha256":FileAccess.get_sha256(asset+".import")}
		var visual:=Visual.new();visual.entry=record;root.add_child(visual);visual.set_process(false);visual.set_physics_process(false);visual.contact.enabled=false;visual.contact.active=false;visual.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0]
		for rate: float in [.65,1.65]:
			for fps: int in [30,60]:
				for pair: Array in [["Idle","Walk"],["Walk","Run"],["Run","Walk"],["Run","Attack"],["Attack","Idle"],["Run","AttackBow"],["Run","Cast"],["Run","Cast2"],["Run","Pillage"],["Run","Death"],["Run","Death2"]]:
					for phase: float in [.31,.74]:
						visual.animator.stop();visual.animator.speed_scale=rate;visual.dead=false;visual.play(pair[0],0.);visual.animator.seek(visual.animator.get_animation(pair[0]).length*phase,true);visual.animator.advance(0.);visual.dead=str(pair[1]).begins_with("Death");visual.play(pair[1],.18)
						for frame in 30:
							visual._process(1./fps);visual.animator.advance(1./fps);visual.skeleton.force_update_all_bone_transforms();visual.update_landmarks();var box:=Geometry.deformed_bounds(mesh,visual.skeleton);samples+=1
							var expected:=0.;var lifts: Array[float]=visual.contact.source_lifts()
							if not visual.dead and lifts[0]>=.015 and lifts[1]>=.015:
								var raw:=source_minimum(visual,mesh)
								if raw>=.015:expected=raw;airborne_cases+=1;maximum_airborne=maxf(maximum_airborne,raw)
							maximum=maxf(maximum,absf(box.position.y-expected))
							check(absf(box.position.y-expected)<.008,"Complete actual mixed source skin preserves measured source clearance");check(visual.position.is_zero_approx() and visual.model.position.x==0. and visual.model.position.z==0.,"Mixed support keeps native coordinates and horizontal source offset");check((visual.global_transform*(visual.get_meta("pick_bounds") as AABB)).grow(.001).encloses(box),"Mixed-pose bounds contain the complete weighted skin")
							if absf(box.position.y-expected)>=.008:rows.append({"kind":record.kind,"rate":rate,"fps":fps,"pair":pair,"phase":phase,"frame":frame,"floor_m":box.position.y,"source_clearance_m":expected})
					await process_frame
		for part: MeshInstance3D in visual.model.find_children("*","MeshInstance3D",true,false):
			for surface in part.mesh.get_surface_count():part.set_surface_override_material(surface,null)
		visual.free()
	for name in runtime:check(runtime[name]==FileAccess.get_sha256("res://Presentation/"+str(name)),"Runtime/test inputs unchanged throughout flat source transitions")
	check(preparation_pin==FileAccess.get_sha256(preparation),"Preparation unchanged throughout flat source transitions")
	for kind in assets:
		var pin: Dictionary=assets[kind];check(pin.asset_sha256==FileAccess.get_sha256(pin.path) and pin.import_sha256==FileAccess.get_sha256(str(pin.path)+".import"),"Exact asset/import unchanged throughout flat source transitions")
	FileAccess.open("res://../outputs/creatures/juka/transitions.json",FileAccess.WRITE).store_string(JSON.stringify({"runtime_sha256":runtime,"assets":assets,"preparation_sha256":preparation_pin,"samples":samples,"checks":checks,"failures":failures,"test_sha256":FileAccess.get_sha256("res://Presentation/JukaTransitionTests.gd"),"visual_sha256":FileAccess.get_sha256("res://Presentation/SourceJukaVisual.gd"),"ground_helper_sha256":FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd"),"maximum_source_clearance_error_m":maximum,"airborne_cases":airborne_cases,"maximum_airborne_height_m":maximum_airborne,"failed_samples":rows,"scope":"Actual mixed full skins with current SourceJukaVisual; independent complete weighted bounds and measured two-foot airborne source clearance at30/60Hz and slow/fast rates, native coordinates and selection envelope. Terrain modifier disabled; finite-plane rendered transitions remain separate. No accepted routes."}));print("SOURCE JUKA MIXED SKINS: ",samples," skins / ",failures," clearance misses; max ",maximum);quit(1 if failures else 0)
