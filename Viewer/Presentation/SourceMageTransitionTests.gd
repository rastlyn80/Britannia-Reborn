extends SceneTree
const Visual=preload("res://Presentation/SourceMageVisual.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;if failures<12:push_error(label)
func run() -> void:
	var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/mages/preparation.json"));var rows: Array=[];var maximum:=0.;var samples:=0
	for record: Dictionary in prep.models:
		var visual:=Visual.new();visual.entry=record;root.add_child(visual);visual.set_process(false);visual.set_physics_process(false);visual.contact.enabled=false;visual.contact.active=false;visual.animator.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL;var mesh: MeshInstance3D=visual.model.find_children("*","MeshInstance3D",true,false)[0]
		for rate: float in [.65,1.65]:
			for fps: int in [30,60]:
				for pair: Array in [["Idle","Walk"],["Walk","Run"],["Run","Walk"],["Run","Attack"],["Attack","Idle"],["Run","Cast2"],["Run","Pillage"],["Run","Death"]]:
					for phase: float in [.31,.74]:
						visual.animator.stop();visual.animator.speed_scale=rate;visual.dead=false;visual.play(pair[0],0.);visual.animator.seek(visual.animator.get_animation(pair[0]).length*phase,true);visual.animator.advance(0.);visual.play(pair[1],.18)
						for frame in 30:
							visual._process(1./fps);visual.animator.advance(1./fps);visual.skeleton.force_update_all_bone_transforms();visual.update_landmarks();var box:=Geometry.deformed_bounds(mesh,visual.skeleton);samples+=1;maximum=maxf(maximum,absf(box.position.y))
							check(absf(box.position.y)<.008,"Complete actual mixed source skin remains grounded");check(visual.position.is_zero_approx() and visual.model.position.x==0. and visual.model.position.z==0.,"Mixed support keeps native coordinates and horizontal source offset");check((visual.global_transform*(visual.get_meta("pick_bounds") as AABB)).grow(.001).encloses(box),"Mixed-pose bounds contain the complete weighted skin")
							if absf(box.position.y)>=.008:rows.append({"kind":record.kind,"rate":rate,"fps":fps,"pair":pair,"phase":phase,"frame":frame,"floor_m":box.position.y})
					await process_frame
		for part: MeshInstance3D in visual.model.find_children("*","MeshInstance3D",true,false):
			for surface in part.mesh.get_surface_count():part.set_surface_override_material(surface,null)
		visual.free()
	FileAccess.open("res://../outputs/creatures/mages/transitions.json",FileAccess.WRITE).store_string(JSON.stringify({"samples":samples,"checks":checks,"failures":failures,"test_sha256":FileAccess.get_sha256("res://Presentation/SourceMageTransitionTests.gd"),"visual_sha256":FileAccess.get_sha256("res://Presentation/SourceMageVisual.gd"),"ground_helper_sha256":FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd"),"maximum_floor_error_m":maximum,"failed_samples":rows,"scope":"Actual mixed full skins with current SourceMageVisual; independent complete weighted bounds at30/60Hz and slow/fast rates, native coordinates and selection envelope. Terrain modifier disabled; finite-plane rendered transitions remain separate. No accepted routes."}));print("SOURCE MAGE MIXED SKINS: ",samples," skins / ",failures," floor misses; max ",maximum);quit(1 if failures else 0)
