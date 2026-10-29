extends SceneTree
const Avatar=preload("res://Presentation/HumanAvatar.gd")
const Horse=preload("res://Presentation/HorseVisual.gd")
var checks:=0
var failures:=0
var rows: Array=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func run() -> void:
	var stage:=Node3D.new();root.add_child(stage)
	var floor_body:=StaticBody3D.new();stage.add_child(floor_body)
	var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(12.,.1,12.);collider.shape=box;collider.position.y=-.05;floor_body.add_child(collider)
	for female in [false,true]:
		var actor:=Avatar.new();actor.initial_body=401 if female else 400;stage.add_child(actor);actor.set_physics_process(false)
		var plate:=Node3D.new();plate.name="Nameplate";actor.add_child(plate)
		var picker:=StaticBody3D.new();picker.set_meta("server_mobile",1);picker.collision_layer=4;picker.collision_mask=0;var pick_shape:=CollisionShape3D.new();pick_shape.shape=CapsuleShape3D.new();picker.add_child(pick_shape);actor.add_child(picker)
		for body: int in Horse.BODIES:
			for hue in [0,53,1153,0x8000|53]:
				var worn: Array=[{"id":0x1415},{"id":0x1411},{"id":0x1410},{"id":0x1414},{"id":0x170b},{"id":Horse.BODIES[body],"layer":25,"hue":hue}]
				actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn)
				actor.rider_contact.begin_mount(false)
				check(actor.horse_visual.native_body==body and actor.horse_visual.native_hue==hue,"Body, mount graphic and full raw hue are server-driven on both riders")
				check(ResourceLoader.exists(Horse.REGIONS_PATH) and actor.horse_visual.get_meta("coat_name")==Horse.COATS[body][0],"The matched native body selects its prepared coat regions deterministically")
				check(actor.transform==Transform3D.IDENTITY,"Appearance changes never move the authoritative actor")
		for family in [[{"id":0x1415},{"id":0x1411},{"id":0x170b}],[{"id":0x1f03},{"id":0x1539},{"id":0x170b}],[{"id":0x1517},{"id":0x1537},{"id":0x170b}]]:
			var worn: Array=family.duplicate(true);worn.append({"id":0x3e9f,"layer":25})
			actor.apply_server_appearance({"body":actor.initial_body,"hue":1002},worn)
			for mode in ["mount","dismount"]:
				for phase in [0.,.1,.2,.3,.4,.5,.6,.7,.8,.9,.99]:
					actor.human_visual.play("Rider_Idle",0.);actor.animator.seek(0.,true);actor.animator.pause()
					actor.rider_contact.mode=mode;actor.rider_contact.progress=phase;actor.rider_contact.finished=false;actor.rider_contact.transition_duration=100000.
					await process_frame;await process_frame
					var rig: Skeleton3D=actor.human_visual.skeleton;var sane:=true
					for bone in rig.get_bone_count():sane=sane and rig.get_bone_global_pose(bone).is_finite()
					var reach: Array=actor.rider_contact.transition_foot_errors
					check(sane and actor.transform==Transform3D.IDENTITY and reach.size()==2 and reach[0]<.025 and reach[1]<.025,"Finite mount/dismount poses keep both feet within 25 mm of their authored targets without moving the server root")
					var t: float=actor.rider_contact.climb_phase();var right: Vector3=actor.rider_contact.foot_path(false,t,actor.horse_visual.seat())
					var local: Vector3=actor.horse_visual.seat().affine_inverse()*right
					if absf(local.x)<.20:check(local.y>.08 and actor.rider_contact.transition_foot_errors[1]<.06,"The fitted leg clears the saddle while crossing the horse centre")
					rows.append({"female":female,"mode":mode,"phase":phase,"finite":sane,"foot_errors_m":actor.rider_contact.transition_foot_errors.duplicate(),"root":str(actor.transform)})
		actor.rider_contact.begin_mount();actor.rider_contact.transition_duration=1.45;actor.animate(true,.6,.1,9.75)
		await create_timer(.35).timeout
		check(actor.rider_contact.mode=="seated","Movement safely completes a climb without delaying native movement")
		actor.apply_server_appearance({"body":actor.initial_body},[])
		check(actor.retiring_horse and not actor.human_visual.mounted_live_enabled,"Server unequip is immediate while only the visual dismount continues")
		actor.receive_native_action({"body":actor.initial_body,"protocol":"new","type":11})
		check(actor.horse_visual==null and actor.human_visual.action_clip=="Cast","An on-foot action safely interrupts dismount and plays immediately")
		await process_frame;await process_frame
		var offset: Vector3=actor.ground_visual_offset
		check(absf(plate.position.x-offset.x)<.001 and absf(pick_shape.position.x-offset.x)<.001 and (actor.get_meta("camera_visual_offset") as Vector3).distance_to(actor.global_basis*offset)<.001,"Dismount camera, nameplate and native picking follow the visual body beside the returned horse")
		actor.apply_server_appearance({"body":actor.initial_body},[{"id":0x3e9f,"layer":25}]);actor.apply_server_appearance({"body":actor.initial_body},[])
		actor.apply_server_appearance({"body":actor.initial_body},[{"id":0x3ea0,"layer":25,"hue":53}])
		check(not actor.retiring_horse and actor.horse_visual.native_body==0xe2 and actor.horse_visual.native_hue==53,"A remount during dismount replaces appearance without a stale ghost")
		var ceiling:=StaticBody3D.new();var ceiling_shape:=CollisionShape3D.new();var ceiling_box:=BoxShape3D.new();ceiling_box.size=Vector3(3.,.1,3.);ceiling_shape.shape=ceiling_box;ceiling.position.y=3.25;ceiling.add_child(ceiling_shape);stage.add_child(ceiling)
		await physics_frame;await process_frame
		var anchor:=actor.transform
		actor.rider_contact.begin_mount();actor._physics_process(.016)
		check(actor.rider_contact.mode=="seated" and actor.has_meta("mount_transition_skipped") and actor.transform==anchor,"A low ceiling skips only the cosmetic climb, retaining the server-confirmed mount")
		ceiling.free()
		actor.free()
	var loose:=Horse.new();stage.add_child(loose)
	for tilt in [Vector2.ZERO,Vector2(.12,0.),Vector2(-.12,0.),Vector2(0.,.10),Vector2(0.,-.10)]:
		floor_body.rotation=Vector3(tilt.x,0,tilt.y)
		for frame in 15:await physics_frame;await process_frame
		loose.animator.play("idle");loose.animator.seek(0.,true);loose.animator.pause()
		for frame in 10:await physics_frame;await process_frame
		check(loose.contact.contacts.size()==4,"Four real physics support rays find the bounded flat/slope surface")
		var errors: Array=loose.contact.hoof_errors
		var good:=errors.size()>0
		for value: float in errors:good=good and value<.045
		check(good and absf(loose.model.rotation.x)<.27 and absf(loose.model.rotation.z)<.18,"Stance hoof fitting and body slope tilt remain bounded")
		rows.append({"slope":str(tilt),"hoof_errors_m":errors.duplicate(),"contacts":loose.contact.contacts.size()})
	floor_body.rotation.x=.9
	for frame in 3:await physics_frame;await process_frame
	check(loose.contact.contacts.is_empty(),"Steep unsupported faces are rejected rather than pulling hooves through terrain")
	check(loose.animator.has_animation("gallop") and loose.animator.has_animation("hit") and loose.animator.has_animation("death"),"Authored gait/reaction additions are installed alongside unchanged source clips")
	check(loose.receive_action({"protocol":"new","type":4}) and loose.current_clip=="hit","Native animal hit requests reach the new reaction")
	loose.action_remaining=0.;loose.play_gait(true,9.75)
	check(loose.current_clip=="gallop","Fast native travel uses the authored gait rather than only speeding up canter")
	check(loose.receive_action({"protocol":"new","type":3}) and loose.dead and not loose.contact.enabled,"Native animal death holds its authored pose without ground IK fighting it")
	loose.free();stage.free()
	var file:=FileAccess.open("res://../outputs/horse-polish/runtime-validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":rows,"scope":"Both sexes; raw hues/identities; finite leg-over poses in three outfits; movement/action/remount interruption; actual bounded slope support; authored gait/reaction routing. Finite sampled evidence, not universal cloth collision or captured biomechanics."},"\t"));file.close()
	print("HORSE POLISH: ",checks," checks / ",failures," failures");quit(1 if failures else 0)
