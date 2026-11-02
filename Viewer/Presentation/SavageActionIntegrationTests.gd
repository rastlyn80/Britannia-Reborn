extends SceneTree
## Exercise the actual avatar/action/controller path without a server or GPU.
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Profiles=preload("res://Presentation/HumanNPCProfiles.gd")
const Actions=preload("res://Presentation/HumanActions.gd")
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const Dance=preload("res://Presentation/SavageDanceRetarget.gd")
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(90.).timeout.connect(func():push_error("Savage action integration deadline");quit(1))
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func expected_lift(samples: Array,time: float) -> float:
	for index in range(1,samples.size()):
		if float(samples[index].time)<time:continue
		var a: Dictionary=samples[index-1];var b: Dictionary=samples[index]
		return lerpf(a.source_lift_m,b.source_lift_m,clampf((time-float(a.time))/maxf(.000001,float(b.time)-float(a.time)),0.,1.))
	return float(samples[-1].source_lift_m)
func run() -> void:
	Profiles.load_index();var previous:=Profiles.entries.duplicate(true)
	var accepted_path:="res://local-art/human-npcs/accepted-index.json"
	var accepted_sha:=FileAccess.get_sha256(accepted_path) if FileAccess.file_exists(accepted_path) else "absent"
	var prep: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://local-art/human-npcs/savages/dance/preparation.json"))
	var records: Array=[]
	for body: int in [183,184]:
		var female:=body==184;var gender:="female" if female else "male"
		var asset:="res://local-art/human-npcs/savages/dance/"+gender+"-tribal-dance.res"
		Profiles.entries[body]={"body":body,"female":female,"skin":"savage","status":"prepared","tribal_dance":{"asset":asset,"sha256":FileAccess.get_sha256(asset)}}
		var actor:=Avatar.new();actor.initial_body=body;root.add_child(actor)
		actor.set_process(false);actor.set_physics_process(false);actor.position=Vector3(7.,3.,-5.)
		actor.apply_server_appearance({"body":body,"hue":0,"flags":0},[])
		var human: Node3D=actor.human_visual;human.set_process(false)
		var rig: Skeleton3D=human.skeleton
		var request:={"protocol":"classic","body":body,"action":111,"frames":5,"delay":0,"repeat_count":1,"repeat":false,"reverse":false}
		check(Actions.resolve(request)=="Savage_Dance","Prepared native identity resolves classic111 to its special human clip")
		check(Actions.resolve(request,true).is_empty(),"Unproved mounted tribal dance stays unsupported")
		var ordinary:=request.duplicate(true);ordinary.body=400
		check(Actions.resolve(ordinary).is_empty(),"Ordinary humans do not acquire an NPC-only action")
		actor.foot_contact.contacts={"l":{"position":Vector3(7.,3.,-5.),"normal":Vector3.UP},"r":{"position":Vector3(7.,3.,-5.),"normal":Vector3.UP}}
		actor.foot_contact.weights={"l":1.,"r":1.}
		check(actor.receive_native_action(request),"Actual avatar accepts the prepared classic111 request")
		check(actor.foot_contact.active and not bool(actor.foot_contact.call("leg_ik_enabled")),"Standing leg IK disables immediately while complete-skin support remains available")
		check(human.action_clip=="Savage_Dance" and is_equal_approx(human.action_duration,.8),"Native five-frame/delay0 duration is800ms, independently of source clip length")
		check(human.native_action==request and not human.action_reverse and human.action_cycles==1,"Native request fields and finite forward playback survive")
		var clip: Animation=human.animator.get_animation("Savage_Dance")
		check(is_equal_approx(human.action_rate,clip.length/.8),"Actual player rate follows native packet timing")
		# Let the ordinary entry blend expire, then compare actual controller-held poses.
		# This does not certify mixed-pose entry/exit clearance or sloped terrain.
		human.animator.advance(.2)
		var source: Dictionary={}
		for row: Dictionary in prep.models:
			if row.gender==gender:source=row
		var worst_floor:=0.;var highest:=0.
		var phases: Array[float]=[.137,.283,.463,.617,.829,.973]
		var peak: Dictionary=source.samples[0]
		for sample: Dictionary in source.samples:
			if float(sample.source_lift_m)>float(peak.source_lift_m):peak=sample
		phases.append(float(peak.time)/clip.length)
		for phase: float in phases:
			actor.animate(false,0.,.016)
			human.animator.seek(clip.length*phase,true);human.animator.pause();rig.force_update_all_bone_transforms()
			check(not bool(actor.foot_contact.call("leg_ik_enabled")) and human.action_clip=="Savage_Dance","Idle controller cannot replace tribal motion or turn standing leg IK back on")
			check(actor.position==Vector3(7.,3.,-5.),"Dance leaves the authoritative character root unchanged")
			for track in clip.get_track_count():
				var bone:=rig.find_bone(str(clip.track_get_path(track).get_subname(0)))
				if clip.track_get_type(track)==Animation.TYPE_POSITION_3D:
					check(rig.get_bone_pose_position(bone).distance_to(clip.position_track_interpolate(track,clip.length*phase))<.000001,"Actual avatar retains all source-adapted position tracks")
				else:
					check(1.-absf(rig.get_bone_pose_rotation(bone).normalized().dot(clip.rotation_track_interpolate(track,clip.length*phase).normalized()))<.000001,"Actual avatar retains all source-adapted rotation tracks")
			var minimum:=Geometry.deformed_bounds(Dance.body(human),rig).position.y-actor.global_position.y
			var wanted:=expected_lift(source.samples,clip.length*phase)
			worst_floor=maxf(worst_floor,absf(minimum-wanted));highest=maxf(highest,minimum)
			check(absf(minimum-wanted)<.004,"Actual body keeps prepared complete-skin clearance and positive source lift")
		check(highest>.10,"Real avatar still leaves the ground during the dance")
		var active_library: AnimationLibrary=human.animator.get_animation_library("")
		actor.apply_server_appearance({"body":body,"hue":53,"flags":0},[])
		check(human.animator.get_animation_library("")==active_library and human.action_clip=="Savage_Dance","A hue/equipment refresh does not restart or discard the action library")
		human._process(.79);check(human.action_clip=="Savage_Dance","Native action stays active before its800ms boundary")
		human._process(.011);actor.animate(false,0.,.016)
		check(human.action_clip.is_empty() and actor.foot_contact.active,"One-shot ends and ordinary foot contact returns after native duration")
		check(actor.receive_native_action(request),"Another native dance restarts correctly")
		actor.apply_server_appearance({"body":400 if not female else 401,"hue":1002,"flags":0},[])
		check(human.action_clip.is_empty() and not human.animator.has_animation("Savage_Dance"),"Returning to an ordinary human cancels and removes NPC-only motion")
		actor.animate(false,0.,.016);check(actor.foot_contact.active,"Normal human restores standing contact after profile removal")
		records.append({"body":body,"female":female,"asset_sha256":FileAccess.get_sha256(asset),"native_duration_s":.8,"sampled_floor_error_m":worst_floor,"preserved_lift_m":highest,"settled_off_grid_poses":6,"source_peak_pose":float(peak.time)})
		actor.free()
	Profiles.entries=previous
	check((FileAccess.get_sha256(accepted_path) if FileAccess.file_exists(accepted_path) else "absent")==accepted_sha,"Integration trial never changes the accepted body index")
	var report:={"checks":checks,"failures":failures,"models":records,"runtime_sha256":{},"scope":"Headless actual HumanAvatar request/controller/settled skin, native-format timing, modifier suspension, refresh and reversion. Prepared profiles injected only in this test. No actual server, GPU, blended entry/exit, terrain, clothing, death or family acceptance."}
	for name in ["SavageActionIntegrationTests.gd","HumanNPCMotion.gd","HumanVisual.gd","HumanAvatar.gd","HumanActions.gd","HumanNPCProfiles.gd","FootContact.gd"]:report.runtime_sha256[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var file:=FileAccess.open("res://../work/creatures/savages/action-integration-tests.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SAVAGE ACTION INTEGRATION: ",checks," checks / ",failures," failures; CPU prepared profiles only");quit(1 if failures else 0)
