extends Node3D

var animator := AnimationPlayer.new()
var facing := 0.0
var walking := false
var current_clip := "Idle"
var visual_root := Node3D.new()
var displayed_speed := 0.0
var moving_grace := 0.0
var foot_contact := preload("res://Presentation/FootContact.gd").new()
var ground_offset := 0.0
var jump := preload("res://Presentation/JumpMotion.gd").new()

func _ready() -> void:
	var model: Node3D = load("res://Art/Quaternius/Character/Superhero_Male_FullBody.gltf").instantiate()
	add_child(visual_root)
	visual_root.add_child(model)
	var skeleton: Skeleton3D = model.find_children("*","Skeleton3D",true,false)[0]
	# Standard supplies a full body rather than a separate head. Keep its head,
	# eyes and brows; the compatible outfit supplies the rest of the body.
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		if mesh.name == "SuperHero_Male":
			var original: StandardMaterial3D = mesh.get_active_material(0)
			var head := ShaderMaterial.new()
			var shader := Shader.new()
			shader.code = "shader_type spatial; uniform sampler2D skin_texture : source_color; varying float bind_height; void vertex(){ bind_height=VERTEX.y; } void fragment(){ if(bind_height<1.53){discard;} ALBEDO=texture(skin_texture,UV).rgb; ROUGHNESS=0.85; }"
			head.shader = shader
			head.set_shader_parameter("skin_texture",original.albedo_texture)
			mesh.material_override = head
	var outfit: Node3D = load("res://Art/Quaternius/Outfit/Male_Peasant.gltf").instantiate()
	var outfit_rig: Skeleton3D = outfit.find_children("*","Skeleton3D",true,false)[0]
	for bone in skeleton.get_bone_count():
		var matching := outfit_rig.find_bone(skeleton.get_bone_name(bone))
		if matching >= 0: skeleton.set_bone_rest(bone,outfit_rig.get_bone_rest(matching))
	skeleton.reset_bone_poses()
	skeleton.add_child(foot_contact)
	for mesh in outfit.find_children("*","MeshInstance3D",true,false):
		mesh.owner = null
		mesh.get_parent().remove_child(mesh)
		skeleton.add_child(mesh)
		mesh.skeleton = NodePath("..")
	outfit.free()
	var hood: Node3D = load("res://Art/Quaternius/Outfit/Male_Ranger_Head_Hood.gltf").instantiate()
	for mesh in hood.find_children("*","MeshInstance3D",true,false):
		mesh.owner = null
		mesh.get_parent().remove_child(mesh)
		skeleton.add_child(mesh)
		mesh.skeleton = NodePath("..")
	hood.free()
	var animations: Node = load("res://Art/Quaternius/Animation/UAL1_Standard.glb").instantiate()
	var source: AnimationPlayer = animations.find_child("AnimationPlayer",true,false)
	var library := AnimationLibrary.new()
	for clip in ["Idle","Walk","Jog_Fwd","Sprint","Jump_Start","Jump","Jump_Land"]:
		var source_rig: Skeleton3D = animations.find_children("*","Skeleton3D",true,false)[0]
		var animation: Animation = preload("res://Presentation/AnimationRetarget.gd").retarget(source.get_animation(clip),source_rig,skeleton)
		animation.loop_mode = Animation.LOOP_NONE if clip in ["Jump_Start","Jump_Land"] else Animation.LOOP_LINEAR
		library.add_animation(clip,animation)
	model.add_child(animator)
	animator.add_animation_library("",library)
	animator.play("Idle")
	animations.free()

func animate(moving: bool, direction: float, delta: float, speed: float = 2.44) -> void:
	facing = direction
	rotation.y = lerp_angle(rotation.y,facing,1.0-exp(-10.0*delta))
	if moving: moving_grace = 0.10
	else: moving_grace = maxf(0,moving_grace-delta)
	moving = moving or moving_grace > 0
	if moving and displayed_speed < 0.1: displayed_speed = speed
	displayed_speed = lerpf(displayed_speed,speed if moving else 0.0,1.0-exp(-12.0*delta))
	walking = moving
	var threshold := 3.35 if current_clip == "Sprint" else 3.8
	var clip := ("Sprint" if displayed_speed > threshold else ("Jog_Fwd" if displayed_speed > (1.3 if current_clip == "Jog_Fwd" else 1.65) else "Walk")) if moving else "Idle"
	if jump.airborne: clip = "Jump_Start" if jump.elapsed < 0.15 else "Jump"
	elif jump.landing_time > 0: clip = "Jump_Land"
	if current_clip != clip:
		current_clip = clip
		var phase := animator.current_animation_position/maxf(0.001,animator.current_animation_length)
		var previous := animator.current_animation
		animator.play(clip,0.20 if clip == "Idle" else 0.12)
		if clip in ["Walk","Jog_Fwd","Sprint"] and previous in ["Walk","Jog_Fwd","Sprint"]:
			animator.seek(fmod(phase,1.0)*animator.get_animation(clip).length)
	# Presentation pace follows measured render speed; no animation root motion
	# is allowed to move the server-authoritative avatar root. Native paces are
	# measured from retargeted stance-foot travel: Walk 1.02, Jog 2.66, Sprint 3.50 m/s.
	animator.speed_scale = clampf(displayed_speed/(3.50 if clip == "Sprint" else (2.66 if clip == "Jog_Fwd" else 1.02)),0.75,2.0) if moving and not clip.begins_with("Jump") else 1.0
	visual_root.position.y = jump.height+ground_offset
	foot_contact.grounded = not jump.airborne
	foot_contact.body_offset = ground_offset
	var nameplate := get_node_or_null("Nameplate")
	if nameplate: nameplate.position.y = 2.2+jump.height

func _physics_process(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	foot_contact.sample(space,global_position.y)
	var target := 0.0
	if not jump.airborne:
		var samples: Array[float] = []
		var forward := global_basis.z*0.18
		for offset in [Vector3.ZERO,forward,-forward]:
			var query := PhysicsRayQueryParameters3D.create(global_position+offset+Vector3.UP*0.65,global_position+offset-Vector3.UP*0.65,1)
			var hit := space.intersect_ray(query)
			if not hit.is_empty() and hit.normal.y >= 0.65: samples.append(float(hit.position.y)-global_position.y)
		if not samples.is_empty():
			for height in samples: target += height/samples.size()
			target = clampf(target,-0.45,0.45)
	ground_offset = lerpf(ground_offset,target,1.0-exp(-12.0*delta))

func reset_presentation() -> void:
	jump.reset()
	ground_offset = 0
	foot_contact.contacts.clear()
	foot_contact.weights.clear()
	visual_root.position.y = 0
