extends Node3D

var animator := AnimationPlayer.new()
var facing := 0.0
var walking := false
var current_clip := "Idle"

func _ready() -> void:
	var model: Node3D = load("res://Art/Quaternius/Character/Superhero_Male_FullBody.gltf").instantiate()
	add_child(model)
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
	for mesh in outfit.find_children("*","MeshInstance3D",true,false):
		mesh.owner = null
		mesh.get_parent().remove_child(mesh)
		skeleton.add_child(mesh)
		mesh.skeleton = NodePath("..")
	outfit.free()
	var animations: Node = load("res://Art/Quaternius/Animation/UAL1_Standard.glb").instantiate()
	var source: AnimationPlayer = animations.find_child("AnimationPlayer",true,false)
	var library := AnimationLibrary.new()
	for clip in ["Idle","Walk","Jog_Fwd"]:
		var animation: Animation = source.get_animation(clip).duplicate(true)
		animation.loop_mode = Animation.LOOP_LINEAR
		library.add_animation(clip,animation)
	model.add_child(animator)
	animator.add_animation_library("",library)
	animator.play("Idle")
	animations.free()

func animate(moving: bool, direction: float, delta: float, speed: float = 2.44) -> void:
	facing = direction
	rotation.y = lerp_angle(rotation.y,facing,1.0-exp(-14.0*delta))
	walking = moving
	var clip := ("Jog_Fwd" if speed > 1.8 else "Walk") if moving else "Idle"
	if current_clip != clip:
		current_clip = clip
		animator.play(clip,0.16)
	# Presentation pace follows measured render speed; no animation root motion
	# is allowed to move the server-authoritative avatar root.
	animator.speed_scale = clampf(speed/(2.6 if clip == "Jog_Fwd" else 1.2),0.5,2.0) if moving else 1.0
