extends Node3D
## Private original-rig trial. No body/mount route or server authority changes.
const CLIPS := ["Idle","Walk","Run","Attack","Hit","Death","Fidget"]
var treatment:="modern"
var model: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var hue:=0
var detail:=.32
func _ready() -> void:
	model=load("res://local-art/ostards/desert-"+treatment+".gltf").instantiate();add_child(model)
	skeleton=model.find_children("*","Skeleton3D",true,false)[0]
	animator=model.find_children("*","AnimationPlayer",true,false)[0]
	var library:=animator.get_animation_library("").duplicate(true);animator.remove_animation_library("");animator.add_animation_library("",library)
	for clip in CLIPS:animator.get_animation(clip).loop_mode=Animation.LOOP_LINEAR if clip in ["Idle","Walk","Run","Fidget"] else Animation.LOOP_NONE
	set_hue(hue);play("Idle")
func set_hue(value: int) -> void:
	hue=value
	if model==null:return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if treatment=="modern":
				var mat:=ShaderMaterial.new();mat.shader=preload("res://Presentation/OstardSurface.gdshader");mat.set_shader_parameter("albedo_texture",source.albedo_texture)
				var palette:=preload("res://Presentation/HumanHue.gd").palette(hue);mat.set_shader_parameter("hue_palette",palette);mat.set_shader_parameter("use_hue",palette!=null);mat.set_shader_parameter("partial_hue",(hue&0x8000)!=0);mat.set_shader_parameter("detail_strength",detail);mesh.set_surface_override_material(surface,mat)
			else:
				# Neutral, identical baseline lighting/material settings for the two
				# source-textured cages; material interpretation is isolated at right.
				var mat: StandardMaterial3D=source.duplicate();mat.roughness=.9;mat.metallic=0.;mesh.set_surface_override_material(surface,mat)
func play(clip: String,blend: float=.12) -> void:animator.play(clip,blend)
