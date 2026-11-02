extends SceneTree
## Asset-backed headless integration; never labelled GPU/native server acceptance.
const Human=preload("res://Presentation/HumanVisual.gd")
const Motion=preload("res://Presentation/HumanNPCMotion.gd")
var checks:=0
var failures:=0
func _initialize() -> void:
	create_timer(60.).timeout.connect(func():push_error("Human NPC motion deadline");quit(1))
	call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var records: Array=[]
	for female in [false,true]:
		var human:=Human.new();human.female=female;root.add_child(human);human.set_process(false)
		var peer:=Human.new();peer.female=female;root.add_child(peer);peer.set_process(false)
		var asset:="res://local-art/human-npcs/savages/dance/"+("female" if female else "male")+"-tribal-dance.res"
		var digest:=FileAccess.get_sha256(asset)
		var profile:={"skin":"savage","tribal_dance":{"asset":asset,"sha256":digest}}
		human.animator.play("Walk",0.,.73);human.animator.seek(.2,true)
		var before:=human.animator.current_animation_position
		check(Motion.configure(human,profile),"Exact prepared gender clip installs")
		check(human.animator.has_animation(Motion.CLIP) and not peer.animator.has_animation(Motion.CLIP),"NPC motion library is isolated from another human sharing cached motion")
		check(human.animator.current_animation=="Walk" and absf(human.animator.current_animation_position-before)<.000001,"Installing one-shot preserves current locomotion and phase")
		check(absf(human.animator.get_playing_speed()-.73)<.000001,"Current custom animation rate survives installation")
		var library:=human.animator.get_animation_library("")
		check(Motion.configure(human,profile) and human.animator.get_animation_library("")==library,"Appearance refresh reuses the same exact installed motion without a reset")
		var clip: Animation=human.animator.get_animation(Motion.CLIP)
		for phase: float in [.037,.163,.419,.691,.947]:
			human.animator.play(Motion.CLIP,0.);human.animator.seek(clip.length*phase,true);human.animator.pause();human.skeleton.force_update_all_bone_transforms()
			for track in clip.get_track_count():
				var path:=clip.track_get_path(track);var bone:=human.skeleton.find_bone(str(path.get_subname(0)))
				check(bone>=0,"Every prepared track resolves on the actual target skeleton")
				if bone<0:continue
				if clip.track_get_type(track)==Animation.TYPE_POSITION_3D:
					check(human.skeleton.get_bone_pose_position(bone).distance_to(clip.position_track_interpolate(track,clip.length*phase))<.000001,"Actual installed position matches an independent off-grid track sample")
				else:
					check(1.-absf(human.skeleton.get_bone_pose_rotation(bone).normalized().dot(clip.rotation_track_interpolate(track,clip.length*phase).normalized()))<.000001,"Actual installed rotation matches independent off-grid track sample")
		human.animator.play("Walk",0.);human.animator.seek(.31,true);human.animator.pause()
		check(not Motion.configure(human,{"skin":"savage","tribal_dance":{"asset":asset,"sha256":"0".repeat(64)}}),"Changed asset cannot satisfy an accepted profile pin")
		check(not human.animator.has_animation(Motion.CLIP),"Invalidated exact motion is removed instead of kept stale")
		check(human.animator.assigned_animation=="Walk" and not human.animator.is_playing() and absf(human.animator.current_animation_position-.31)<.000001,"Removing unsupported motion preserves paused ordinary locomotion")
		check(Motion.configure(human,profile),"The valid motion can be restored after an invalid appearance")
		check(not human.animator.is_playing(),"A paused character stays paused while its library is updated")
		human.animator.play();human.animator.advance(.1)
		check(human.animator.current_animation_position>.31,"Resuming paused locomotion advances rather than keeping a zero custom rate")
		var wrong:=profile.duplicate(true);wrong.tribal_dance.asset=asset.replace("female" if female else "male","male" if female else "female")
		check(not Motion.configure(human,wrong),"Cross-gender motion assets are refused")
		check(Motion.configure(human,profile),"Exact gender motion restores again")
		check(not Motion.configure(human,{}) and not human.animator.has_animation(Motion.CLIP),"Returning to a normal human removes NPC-only motion")
		records.append({"female":female,"asset":asset,"sha256":digest,"off_grid_phases":5,"target_bones":human.skeleton.get_bone_count()})
		human.free();peer.free()
	var report:={"checks":checks,"failures":failures,"models":records,"runtime_sha256":{},"scope":"Actual modern human motion-library isolation, exact gender/hash guard, off-grid tracks and ordinary gait/pause restoration. Headless CPU only; no native111, GPU, terrain, equipment or full NPC acceptance."}
	for name in ["HumanNPCMotion.gd","HumanNPCMotionTests.gd","HumanVisual.gd","HumanMotion.gd"]:report.runtime_sha256[name]=FileAccess.get_sha256("res://Presentation/"+name)
	var file:=FileAccess.open("res://../work/creatures/savages/human-npc-motion-tests.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("HUMAN NPC MOTION: ",checks," checks / ",failures," failures; CPU integration only");quit(1 if failures else 0)
