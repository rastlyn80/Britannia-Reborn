extends Node3D
## Prepared source-rig visual shared by reviews and runtime mount adapters.
## Server appearance and riding authority remain outside the renderer.
const CLIPS := ["Idle","Walk","Run","Attack","Hit","Death","Fidget"]
var treatment:="modern"
var kind:="desert"
var model: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var hue:=0
var detail:=.32
func _ready() -> void:
	var folder:="mounts" if kind in ["kirin","kirin_ethereal","llama","llama_ethereal"] else "ostards"
	if kind.begins_with("bovine_"):folder="animals"
	var asset_kind:="kirin" if kind=="kirin_ethereal" else kind
	model=load("res://local-art/"+folder+"/"+asset_kind+"-"+treatment+".gltf").instantiate();add_child(model)
	skeleton=model.find_children("*","Skeleton3D",true,false)[0]
	animator=model.find_children("*","AnimationPlayer",true,false)[0]
	var library:=animator.get_animation_library("").duplicate(true);animator.remove_animation_library("");animator.add_animation_library("",library)
	for clip in CLIPS:animator.get_animation(clip).loop_mode=Animation.LOOP_LINEAR if clip in ["Idle","Walk","Run","Fidget"] else Animation.LOOP_NONE
	preload("res://Presentation/AnimalPoseLibrary.gd").install(animator,skeleton,"Idle","Death","Eat","LieDown")
	set_hue(hue);play("Idle")
func set_hue(value: int) -> void:
	hue=value
	if model==null:return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source==null:continue # Authored eyes, reins and panniers keep their own materials.
			if treatment=="modern":
				var spectral:=kind in ["ethereal","llama_ethereal","kirin_ethereal"]
				var mat:=ShaderMaterial.new();mat.shader=preload("res://Presentation/OstardEthereal.gdshader") if spectral else preload("res://Presentation/OstardSurface.gdshader");mat.set_shader_parameter("albedo_texture",source.albedo_texture)
				if kind=="llama_ethereal":mat.set_shader_parameter("spectral_tint",Color("99cdef"))
				elif kind=="kirin_ethereal":mat.set_shader_parameter("spectral_tint",Color("c2d2ee"))
				var palette: Texture2D=null if spectral and hue==0x4001 else preload("res://Presentation/HumanHue.gd").palette(hue);mat.set_shader_parameter("hue_palette",palette);mat.set_shader_parameter("use_hue",palette!=null);mat.set_shader_parameter("partial_hue",(hue&0x8000)!=0);mat.set_shader_parameter("detail_strength",detail);mesh.set_surface_override_material(surface,mat)
			else:
				# Neutral, identical baseline lighting/material settings for the two
				# source-textured cages; material interpretation is isolated at right.
				var mat: StandardMaterial3D=source.duplicate();mat.roughness=.9;mat.metallic=0.;mesh.set_surface_override_material(surface,mat)
func play(clip: String,blend: float=.12) -> void:animator.play(clip,blend)
