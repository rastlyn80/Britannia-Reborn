extends "res://Presentation/LegacyAvatar.gd"
## Preserve controller/contact/jump behavior while presenting native humans.
const Human = preload("res://Presentation/HumanVisual.gd")
const Wardrobe = preload("res://Presentation/HumanWardrobe.gd")
var initial_body := 0
var human_visual: Node3D
var native_body := 0

func _ready() -> void:
	if Wardrobe.human(initial_body) and Human.available(Wardrobe.female(initial_body)):
		add_child(visual_root)
		_switch_human(Wardrobe.female(initial_body))
	else: super._ready()

func _switch_human(is_female: bool) -> void:
	if visual_root.get_parent() == null: add_child(visual_root)
	if foot_contact.get_parent(): foot_contact.get_parent().remove_child(foot_contact)
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

func apply_server_appearance(entity: Dictionary, worn: Array) -> void:
	var body := int(entity.get("body",0))
	native_body = body
	if not Wardrobe.human(body):
		if body>0 and human_visual != null:
			if foot_contact.get_parent(): foot_contact.get_parent().remove_child(foot_contact)
			for child in visual_root.get_children():
				visual_root.remove_child(child)
				child.queue_free()
			remove_child(visual_root)
			animator = AnimationPlayer.new()
			human_visual = null
			super._ready()
			set_meta("human_batch",false)
		return
	var sex := Wardrobe.female(body)
	if not Human.available(sex): return
	if human_visual == null or human_visual.female != sex: _switch_human(sex)
	human_visual.set_skin(int(entity.get("hue",1002)))
	human_visual.set_equipment(worn)
	set_meta("native_body",body)

func animate(moving: bool, direction: float, delta: float, speed: float = 2.44) -> void:
	if human_visual == null:
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
	var threshold := 3.35 if current_clip == "Run" else 3.8
	var clip := ("Run" if displayed_speed>threshold else "Walk") if moving else "Idle"
	if jump.airborne: clip = "Jump_Start" if jump.elapsed<.15 else "Jump"
	elif jump.landing_time>0: clip = "Jump_Land"
	current_clip = clip
	human_visual.play(clip,.20 if clip == "Idle" else .12)
	animator.speed_scale = clampf(displayed_speed/(3.0 if clip=="Run" else 1.4),.75,2.) if moving and not clip.begins_with("Jump") else 1.
	visual_root.position.y = jump.height+ground_offset
	foot_contact.grounded = not jump.airborne
	foot_contact.body_offset = ground_offset
	var plate := get_node_or_null("Nameplate")
	if plate: plate.position.y = 2.2+jump.height
