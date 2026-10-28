extends SceneTree
const Visual=preload("res://Presentation/HumanVisual.gd")
const Actions=preload("res://Presentation/HumanActions.gd")
var checks:=0
var failures:=0
var began:=Time.get_ticks_msec()
func _initialize() -> void:call_deferred("run")
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-began>90000:push_error("Human motion test timeout");quit(1)
	return false
func check(ok: bool, label: String) -> void:
	checks+=1
	if ok:print("PASS ",label)
	else:failures+=1;push_error(label)
func grip_snapshot(actor: Node3D) -> Dictionary:
	# Called by modification_processed, while the modified skinning pose is
	# available. Ordinary frame callbacks see the restored animation pose.
	var rig: Skeleton3D=actor.skeleton;var fold: Array=[];var rotations: Dictionary={}
	for finger in ["index","middle","ring","pinky"]:
		var points: Array[Vector3]=[]
		for segment in ["01","02","03"]:points.append(rig.get_bone_global_pose(rig.find_bone(finger+"_"+segment+"_r")).origin)
		var last:=rig.get_bone_global_pose(rig.find_bone(finger+"_03_r"))
		points.append(last.origin+last.basis.y.normalized()*points[1].distance_to(points[2])*.65)
		var length:=0.
		for i in 3:length+=points[i].distance_to(points[i+1])
		fold.append(points[0].distance_to(points[-1])/length)
	for name in ["hand_r","thumb_02_r","index_01_l","middle_02_l","pinky_03_l"]:rotations[name]=rig.get_bone_pose_rotation(rig.find_bone(name))
	return {"fold":fold,"rotations":rotations}
func run() -> void:
	var game:=preload("res://Network/GameSession.gd").new();root.add_child(game);game.set_process(false);game.player.serial=7
	game.feed(PackedByteArray([0x72,1,0,0x32,0]))
	check((int(game.player.flags)&0x40)!=0,"server war-mode confirmation updates the native flag")
	game.feed(PackedByteArray([0x72,0,0,0x32,0]))
	check((int(game.player.flags)&0x40)==0,"server peace confirmation clears only the native war flag")
	var modern:=preload("res://Network/MobileAppearance.gd").action(PackedByteArray([0xe2,0,0,0,7,0,0,0,4,2]))
	modern.body=400
	check(modern.type==0 and modern.subaction==4 and modern.variation==2 and Actions.resolve(modern)=="Sword_A","new native protocol uses type/subaction/variation rather than classic frame timing")
	check(Actions.resolve({"body":17,"protocol":"classic","action":9}).is_empty(),"human attack mapping never leaks onto a monster body")
	check(Actions.resolve({"body":400,"protocol":"classic","action":18}).is_empty(),"unsupported bow/crossbow attacks remain explicit")
	check(Actions.gait(2.44)=="Jog" and Actions.gait(4.88)=="Run" and Actions.gait(1.51,"Jog")=="Jog","native travel speeds select short-stride jog/run with hysteresis")
	var starter:=preload("res://Presentation/HumanWardrobe.gd").resolve([{"id":0x13ff,"layer":1}])
	check(starter.pieces.weapon.asset=="sword" and starter.pieces.weapon.id==0x13ff,"native starter katana selects an armed category while retaining its exact graphic")
	game.free()
	for female in [false,true]:
		var actor:=Visual.new();actor.female=female;root.add_child(actor);actor.set_process(false)
		var tag:="female" if female else "male"
		check(actor.motion_profile.get("clips",{}).size()==43,tag+": complete prepared motion set installed")
		var finite:=true;var paths:=true;var root_fixed:=true;var loops:=true
		var rig: Skeleton3D=actor.skeleton;var start:=actor.global_transform
		var roots: Dictionary={}
		for bone in rig.get_bone_count():
			if rig.get_bone_parent(bone)<0:roots[bone]=rig.get_bone_rest(bone).origin
		for clip in actor.motion_profile.clips:
			var animation: Animation=actor.animator.get_animation(clip)
			for track in animation.get_track_count():
				var path:=animation.track_get_path(track)
				paths=paths and rig.find_bone(str(path.get_subname(0)))>=0
			actor.play(clip,0.)
			for phase in 8:
				actor.animator.seek(animation.length*phase/7.,true)
				for bone in rig.get_bone_count():finite=finite and rig.get_bone_global_pose(bone).is_finite()
				root_fixed=root_fixed and actor.global_transform==start and not roots.is_empty()
				for bone in roots:root_fixed=root_fixed and rig.get_bone_pose_position(bone).distance_to(roots[bone])<.001
			loops=loops and (animation.loop_mode==Animation.LOOP_LINEAR)==bool(actor.motion_profile.clips[clip].loop)
		check(finite and paths,tag+": all 43 clips sampled with finite poses and resolved track paths")
		check(root_fixed,tag+": no animation changes the authoritative mobile root")
		check(loops,tag+": locomotion loops and finite actions retain distinct playback modes")
		var excursion:=0.;var loop_error:=0.
		for clip in ["Walk","Jog","Run","Sprint","Sword_Walk","Sword_Jog","Sword_Run","Sword_Sprint","Unarmed_Walk","Unarmed_Jog","Unarmed_Run","Unarmed_Sprint"]:
			actor.play(clip,0.);actor.animator.seek(0.,true)
			var poses: Array=[]
			for bone in rig.get_bone_count():poses.append(rig.get_bone_pose_rotation(bone))
			var foot:=rig.get_bone_global_pose(rig.find_bone("foot_l")).origin
			for i in 16:
				actor.animator.seek(actor.animator.current_animation_length*i/16.,true)
				excursion=maxf(excursion,foot.distance_to(rig.get_bone_global_pose(rig.find_bone("foot_l")).origin))
			actor.animator.seek(actor.animator.current_animation_length,true)
			for bone in rig.get_bone_count():
				if not rig.get_bone_name(bone).begins_with("robe_"):loop_error=maxf(loop_error,poses[bone].angle_to(rig.get_bone_pose_rotation(bone)))
		check(excursion>.15 and loop_error<.035,tag+": active leg motion and continuous loop endpoints (max %.4f rad)" % loop_error)
		# Check independent arm joints, not just a wrist moving with the torso.
		# An idle arm pasted onto moving legs used to pass the foot/loop checks.
		var shoulder_motion:=INF;var elbow_motion:=INF
		for clip in ["Walk","Jog","Sword_Walk","Sword_Jog","Unarmed_Walk","Unarmed_Jog"]:
			actor.play(clip,0.)
			for side in ["l","r"]:
				for joint in ["upperarm_","lowerarm_"]:
					var rotations: Array[Quaternion]=[];var excursion_arm:=0.
					for sample in 24:
						actor.animator.seek(actor.animator.current_animation_length*sample/24.,true)
						var q:=rig.get_bone_pose_rotation(rig.find_bone(joint+side))
						for previous: Quaternion in rotations:excursion_arm=maxf(excursion_arm,q.angle_to(previous))
						rotations.append(q)
					if joint=="upperarm_":shoulder_motion=minf(shoulder_motion,excursion_arm)
					else:elbow_motion=minf(elbow_motion,excursion_arm)
		check(shoulder_motion>.18 and elbow_motion>.05,tag+": every walking shoulder/elbow moves independently (minimum %.1f / %.1f degrees)" % [rad_to_deg(shoulder_motion),rad_to_deg(elbow_motion)])
		var seam_error:=0.
		for entry in [["Sword_A",13./30.],["Sword_B",16./30.]]:
			actor.play(str(entry[0]),0.);actor.animator.seek(float(entry[1]),true)
			var before: Array=[]
			for bone in rig.get_bone_count():before.append(rig.get_bone_pose_rotation(bone))
			actor.animator.seek(float(entry[1])+1./30.,true)
			for bone in rig.get_bone_count():
				if not rig.get_bone_name(bone).begins_with("robe_"):seam_error=maxf(seam_error,before[bone].angle_to(rig.get_bone_pose_rotation(bone)))
		check(seam_error<.6,tag+": authored sword recoveries have no pose discontinuity (max %.4f rad/frame)" % seam_error)
		actor.set_equipment([{"id":0xf5e}]);check(actor.stance_clip("Jog")=="Sword_Jog" and actor.grip.rotations.size()>=12,tag+": armed movement uses authored arms and a target-calibrated grip")
		actor.set_equipment([{"id":0x1f03},{"id":0xf5e}]);check(actor.stance_clip("Run")=="Sword_Jog" and actor.clothing_clip("Sword_A")=="Sword_A_Cloth",tag+": long garments use short strides and stable attack footwork")
		actor.set_equipment([]);actor.war_mode=true;check(actor.stance_clip("Idle")=="Unarmed_Idle",tag+": unarmed war mode selects a guard stance")
		var request:={"serial":7,"body":401 if female else 400,"protocol":"classic","action":9,"frames":5,"delay":0,"repeat_count":2,"repeat":false,"reverse":false}
		check(actor.request_action(request) and is_equal_approx(actor.action_duration,.8),tag+": native attack starts with sender frame timing")
		actor.animator.seek(.2,true);var phase:=actor.animator.current_animation_position
		actor.set_equipment([{"id":0x13c6},{"id":0xf5e}])
		check(actor.action_clip=="Sword_A" and is_equal_approx(actor.animator.current_animation_position,phase),tag+": equipment changes preserve an in-progress attack")
		actor.set_equipment([{"id":0x1f03},{"id":0xf5e}])
		check(actor.action_clip=="Sword_A_Cloth" and is_equal_approx(actor.animator.current_animation_position,phase),tag+": equipping a robe preserves action timing while changing footwork")
		actor.set_equipment([{"id":0xf5e}])
		actor._process(.81);check(actor.action_cycles==1 and not actor.action_clip.is_empty(),tag+": native repeat count starts its second cycle")
		actor._process(.81);check(actor.action_clip.is_empty(),tag+": finite attack releases locomotion after its final cycle")
		request.reverse=true;request.repeat_count=1;actor.request_action(request)
		check(actor.action_reverse and actor.animator.current_animation_position>actor.animator.current_animation_length-.001,tag+": reverse request starts at the authored end")
		actor.cancel_action();request.action=21;request.reverse=false;actor.request_action(request);actor._process(.81)
		check(actor.action_holding and actor.action_clip=="Death",tag+": death holds its final pose instead of returning to idle")
		request.action=4;actor.request_action(request);check(not actor.action_holding,tag+": a new native action releases the held death pose")
		actor.cancel_action();check(actor.request_action(modern) and actor.action_clip=="Sword_A",tag+": new-format human action reaches the installed clip")
		actor.cancel_action();request.action=999
		check(not actor.request_action(request) and actor.get_meta("unsupported_action").action==999,tag+": unsupported native action remains visible in diagnostics")
		var other:=Visual.new();other.female=female;root.add_child(other);other.set_process(false)
		actor.play("Walk",0.);actor.animator.seek(.1,true);other.play("Walk",0.);other.animator.seek(.4,true)
		check(actor.animator.get_animation("Walk")==other.animator.get_animation("Walk") and is_equal_approx(actor.animator.current_animation_position,.1) and is_equal_approx(other.animator.current_animation_position,.4),tag+": NPCs share immutable motion resources while retaining independent clocks")
		other.free()
		actor.war_mode=false
		var observed: Dictionary={}
		var watcher:=func():observed.merge(grip_snapshot(actor),true)
		actor.grip.modification_processed.connect(watcher)
		var closed:=true;var untouched:=true;var worst_fold:=0.
		for item in [0xf5e,0x1438,0xe81]:
			actor.set_equipment([{"id":item}])
			for base in ["Idle","Walk","Jog","Run","Cast","Sword_A"]:
				actor.play(actor.stance_clip(base),0.);actor.animator.seek(actor.animator.current_animation_length*.31,true);actor.animator.pause()
				var before: Dictionary={}
				for name in ["hand_r","index_01_l","middle_02_l","pinky_03_l"]:before[name]=rig.get_bone_pose_rotation(rig.find_bone(name))
				observed.clear()
				for frame in 3:await process_frame
				closed=closed and observed.has("fold")
				if not observed.has("fold"):continue
				for ratio in observed.fold:worst_fold=maxf(worst_fold,ratio);closed=closed and ratio<.83
				for name in before:untouched=untouched and before[name].angle_to(observed.rotations[name])<.002
		check(closed,tag+": rendered holding fingers stay curled in idle/walk/run/actions with sword, hammer and sceptre (max span %.3f)" % worst_fold)
		check(untouched,tag+": grip leaves the free fingers and carrying wrist animation unchanged")
		var closed_thumb: Quaternion=observed.get("rotations",{}).get("thumb_02_r",Quaternion.IDENTITY)
		actor.set_equipment([]);actor.play("Walk",0.);actor.animator.seek(.3,true);actor.animator.pause();observed.clear()
		for frame in 3:await process_frame
		var released: bool=observed.has("fold") and not actor.grip.holding
		if released:
			for ratio in observed.fold:released=released and ratio>.90
			released=released and closed_thumb.angle_to(observed.rotations.thumb_02_r)>.3
		check(released,tag+": removing the held item releases fingers and thumb to the walk animation")
		actor.grip.modification_processed.disconnect(watcher)
		actor.free()
		var avatar:=preload("res://Presentation/HumanAvatar.gd").new()
		avatar.initial_body=401 if female else 400;root.add_child(avatar)
		avatar.apply_server_appearance({"body":avatar.initial_body,"hue":1002,"flags":0},[{"id":0x13ff,"layer":1}])
		for speed in [.98,2.44]:
			var samples: Array[Quaternion]=[];var arm_travel:=0.
			for frame in 60:
				avatar.animate(true,0.,1./30.,speed);avatar.animator.advance(1./30.)
				var q: Quaternion=avatar.human_visual.skeleton.get_bone_pose_rotation(avatar.human_visual.skeleton.find_bone("upperarm_l"))
				for previous: Quaternion in samples:arm_travel=maxf(arm_travel,q.angle_to(previous))
				samples.append(q)
			var expected: String="Sword_Walk" if speed<1. else "Sword_Jog"
			check(avatar.current_clip==expected and arm_travel>.3,tag+": actual avatar controller keeps the starter-weapon arm swing advancing at %.2f m/s" % speed)
		avatar.free()
	var fallback:=Visual.new();fallback.use_modern_motion=false;root.add_child(fallback)
	check(fallback.motion_profile.is_empty() and fallback.animator.has_animation("Walk") and not fallback.request_action({"body":400,"protocol":"classic","action":9}),"unprepared/previous renderer remains a working locomotion fallback")
	fallback.free()
	print("HUMAN MOTION: %d passed / %d total" % [checks-failures,checks]);quit(0 if failures==0 else 1)
