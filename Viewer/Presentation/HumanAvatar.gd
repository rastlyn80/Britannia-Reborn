extends "res://Presentation/LegacyAvatar.gd"
## Preserve controller/contact/jump behavior while presenting native humans.
const Human = preload("res://Presentation/HumanVisual.gd")
const Wardrobe = preload("res://Presentation/HumanWardrobe.gd")
const Horse = preload("res://Presentation/HorseVisual.gd")
var initial_body := 0
var human_visual: Node3D
var native_body := 0
var server_appearance := {}
var horse_visual: Node3D
var rider_contact: SkeletonModifier3D
var dismount_time:=0.

func _ready() -> void:
	if Horse.BODIES.has(initial_body) and Horse.available():
		add_child(visual_root);_switch_horse(initial_body,0)
	elif Wardrobe.human(initial_body) and Human.available(Wardrobe.female(initial_body)):
		add_child(visual_root)
		_switch_human(Wardrobe.female(initial_body))
	else: super._ready()

func _switch_human(is_female: bool) -> void:
	if visual_root.get_parent() == null: add_child(visual_root)
	if foot_contact.get_parent(): foot_contact.get_parent().remove_child(foot_contact)
	horse_visual=null;rider_contact=null
	foot_contact.active=true
	for child in visual_root.get_children():
		visual_root.remove_child(child)
		child.queue_free()
	human_visual = Human.new()
	human_visual.female = is_female
	visual_root.add_child(human_visual)
	if animator.get_parent() == null: animator.free()
	animator = human_visual.animator
	human_visual.skeleton.add_child(foot_contact)
	var source: Node3D = load("res://Art/Quaternius/Animation/UAL1_Standard.glb").instantiate()
	var source_rig: Skeleton3D = source.find_children("*","Skeleton3D",true,false)[0]
	var player: AnimationPlayer = source.find_children("*","AnimationPlayer",true,false)[0]
	var library: AnimationLibrary = animator.get_animation_library("").duplicate()
	animator.remove_animation_library("")
	animator.add_animation_library("",library)
	for clip in ["Jump_Start","Jump","Jump_Land"]:
		if not human_visual.motion_profile.is_empty():continue
		var animation := preload("res://Presentation/AnimationRetarget.gd").retarget(player.get_animation(clip),source_rig,human_visual.skeleton,{"Head":"head"})
		for track in range(animation.get_track_count()-1,-1,-1):
			var path := animation.track_get_path(track)
			if path.get_subname_count() > 0:
				if human_visual.skeleton.find_bone(str(path.get_subname(0))) < 0:
					animation.remove_track(track)
					continue
				animation.track_set_path(track,NodePath(str(animator.get_node(animator.root_node).get_path_to(human_visual.skeleton))+":"+str(path.get_subname(0))))
		animation.loop_mode = Animation.LOOP_NONE
		library.add_animation(clip,animation)
	source.free()
	current_clip = "Idle"
	set_meta("human_batch",true)

func _switch_horse(body: int,hue: int) -> void:
	if is_instance_valid(animator) and animator.get_parent()==null:animator.free()
	if foot_contact.get_parent():foot_contact.get_parent().remove_child(foot_contact)
	if human_visual!=null:
		if foot_contact.get_parent():foot_contact.get_parent().remove_child(foot_contact)
		human_visual=null;rider_contact=null
	for child in visual_root.get_children():child.free()
	horse_visual=Horse.new();visual_root.add_child(horse_visual);horse_visual.apply_identity(body,hue)
	foot_contact.active=false;horse_visual.skeleton.add_child(foot_contact)
	animator=horse_visual.animator;native_body=body
	set_meta("human_batch",false);set_meta("camera_height",1.4);set_meta("art_status","horse category replacement")

func _sync_mount(worn: Array) -> void:
	var previous: bool=human_visual.mounted_live_enabled
	var item:=Horse.mount_item(worn);var body:=Horse.horse_body(int(item.get("id",0)))
	var supported:=body!=0 and Horse.available()
	human_visual.mounted_live_enabled=supported
	if previous!=supported:
		human_visual.appearance_key="";human_visual.set_equipment(worn)
	set_meta("native_mount",item);set_meta("camera_height",2.05 if supported else 1.4)
	if supported:
		if has_meta("deferred_mount"):remove_meta("deferred_mount")
		if horse_visual==null:
			horse_visual=Horse.new();visual_root.add_child(horse_visual)
			rider_contact=preload("res://Presentation/HorseRider.gd").new();rider_contact.rider=human_visual;rider_contact.horse=horse_visual;human_visual.skeleton.add_child(rider_contact)
			human_visual.cancel_action()
			dismount_time=0.
		horse_visual.apply_identity(body,int(item.get("hue",0)))
		human_visual.grip.holding=true;human_visual.grip.left_holding=true
	else:
		if rider_contact!=null:rider_contact.free();rider_contact=null
		if horse_visual!=null:
			horse_visual.free();horse_visual=null;dismount_time=.3;human_visual.cancel_action()
		if not item.is_empty():set_meta("deferred_mount",item)
		elif has_meta("deferred_mount"):remove_meta("deferred_mount")
	_update_pick_volume(supported or Horse.BODIES.has(native_body))

func _update_pick_volume(large: bool) -> void:
	for child in get_children():
		if child is StaticBody3D and child.has_meta("server_mobile"):
			var shape: CollisionShape3D=child.get_child(0)
			if large:
				var box:=BoxShape3D.new();box.size=Vector3(1.,2.7 if human_visual!=null else 2.1,2.6);shape.shape=box;shape.position.y=box.size.y/2.
			else:
				var capsule:=CapsuleShape3D.new();capsule.radius=.35;capsule.height=1.9;shape.shape=capsule;shape.position.y=.95

func _process(delta: float) -> void:
	if dismount_time>0. and human_visual!=null:
		dismount_time=maxf(0.,dismount_time-delta)
		human_visual.position=human_visual.position.lerp(Vector3.ZERO,minf(1.,delta*18.)) if dismount_time>0. else Vector3.ZERO
		human_visual.quaternion=human_visual.quaternion.slerp(Quaternion.IDENTITY,minf(1.,delta*18.)) if dismount_time>0. else Quaternion.IDENTITY

func apply_server_appearance(entity: Dictionary, worn: Array, details: Dictionary = {}) -> void:
	server_appearance = details.duplicate(true) if not details.is_empty() else preload("res://Network/MobileAppearance.gd").profile(entity,worn)
	set_meta("server_appearance",server_appearance)
	var body := int(entity.get("body",0))
	native_body = body
	if Horse.BODIES.has(body) and Horse.available():
		if horse_visual==null or human_visual!=null:_switch_horse(body,int(entity.get("hue",0)))
		horse_visual.apply_identity(body,int(entity.get("hue",0)));_update_pick_volume(true);return
	if not Wardrobe.human(body):
		set_meta("art_status","missing native body art" if body>0 else "offline fallback")
		if body>0 and (human_visual != null or horse_visual!=null):
			if foot_contact.get_parent(): foot_contact.get_parent().remove_child(foot_contact)
			for child in visual_root.get_children():
				visual_root.remove_child(child)
				child.queue_free()
			remove_child(visual_root)
			animator = AnimationPlayer.new()
			human_visual = null
			horse_visual=null;rider_contact=null;foot_contact.active=true
			super._ready()
			set_meta("human_batch",false)
		return
	var sex := Wardrobe.female(body)
	if not Human.available(sex): return
	if human_visual == null or human_visual.female != sex: _switch_human(sex)
	human_visual.set_skin(int(entity.get("hue",1002)))
	human_visual.war_mode=(int(entity.get("flags",0))&0x40)!=0
	human_visual.set_equipment(worn)
	_sync_mount(worn)
	if not walking and human_visual.action_clip.is_empty():human_visual.play(human_visual.stance_clip("Idle"))
	set_meta("native_body",body)
	set_meta("art_status","human category replacement")

func receive_native_action(request: Dictionary) -> bool:
	if human_visual==null:return false
	for item: Dictionary in server_appearance.get("equipment",[]):
		if int(item.get("layer",0))==25:
			if not (human_visual.mounted_live_enabled or human_visual.rider_preview_enabled) or not preload("res://Presentation/HumanActions.gd").resolve(request,true).begins_with("Rider_"):return false
	return human_visual.request_action(request)

func animate(moving: bool, direction: float, delta: float, speed: float = 2.44) -> void:
	if human_visual == null:
		if horse_visual!=null:
			rotation.y=lerp_angle(rotation.y,direction,1.-exp(-10.*delta));horse_visual.play_gait(moving,speed);visual_root.position.y=ground_offset;return
		super.animate(moving,direction,delta,speed)
		return
	facing = direction
	rotation.y = lerp_angle(rotation.y,facing,1.-exp(-10.*delta))
	if moving: moving_grace = .10
	else: moving_grace = maxf(0.,moving_grace-delta)
	moving = moving or moving_grace>0.
	if moving and displayed_speed<.1: displayed_speed = speed
	displayed_speed = lerpf(displayed_speed,speed if moving else 0.,1.-exp(-12.*delta))
	walking = moving
	if moving and not human_visual.action_clip.is_empty() and human_visual.action_cycles==0 and not human_visual.action_holding:human_visual.cancel_action()
	var threshold := 3.35 if current_clip == "Run" else 3.8
	var clip := ("Run" if displayed_speed>threshold else "Walk") if moving else "Idle"
	if not human_visual.motion_profile.is_empty():
		clip=preload("res://Presentation/HumanActions.gd").gait(displayed_speed,current_clip) if moving else "Idle"
		clip=human_visual.stance_clip(clip)
	if jump.airborne and not human_visual.riding(): clip = "Jump_Start" if jump.elapsed<.15 else "Jump"
	elif jump.landing_time>0 and not human_visual.riding(): clip = "Jump_Land"
	current_clip = clip
	human_visual.play(clip,.20 if clip == "Idle" else .12)
	animator.speed_scale = clampf(displayed_speed/(3.0 if clip=="Run" else 1.4),.75,2.) if moving and not clip.begins_with("Jump") else 1.
	if not human_visual.motion_profile.is_empty():
		var pace: float=float(human_visual.motion_profile.clips.get(clip,{}).get("native_speed_mps",1.))
		animator.speed_scale=clampf(displayed_speed/maxf(.1,pace),.65,1.8) if moving and preload("res://Presentation/HumanActions.gd").locomotion(clip) else 1.
		if not human_visual.action_clip.is_empty():animator.speed_scale=1.
	if horse_visual!=null:
		horse_visual.play_gait(moving,displayed_speed)
		# Horse and human clips have independent source durations. Seat/feet are
		# constrained to animated sockets instead of assuming their phases match.
		animator.speed_scale=horse_visual.animator.speed_scale if human_visual.action_clip.is_empty() else 1.
	visual_root.position.y = (0. if human_visual.riding() else jump.height)+ground_offset
	foot_contact.grounded = not jump.airborne and not human_visual.riding() and not (human_visual.rider_preview_enabled and human_visual.action_clip.begins_with("Rider_"))
	if human_visual.action_clip=="Death":foot_contact.grounded=false
	foot_contact.body_offset = ground_offset
	var plate := get_node_or_null("Nameplate")
	if plate: plate.position.y = 3. if human_visual.riding() else 2.2+jump.height
