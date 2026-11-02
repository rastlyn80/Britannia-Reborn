extends "res://Presentation/SmallSnakeVisual.gd"
## Original nonstandard rigs; support their plane without inventing foot IK.
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
var support_skin: Dictionary={}
var blend_remaining:=0.
var death_lift:=Vector3.ZERO
func _ready() -> void:
	super._ready()
	assert(contact.feet.is_empty(),"Amorphous source must use plane-only support")
	support_skin=Ground.skin_points(model.find_children("*","MeshInstance3D",true,false)[0],skeleton)
	animator.mixer_applied.connect(support_death_blend)
func play(clip: String,blend: float=.12) -> void:
	blend_remaining=blend+.04 if blend>0. else 0.
	super.play(clip,blend)
func receive_action(request: Dictionary) -> bool:
	var accepted:=super.receive_action(request)
	if accepted:blend_remaining=maxf(blend_remaining,.16)
	return accepted
func support_death_blend() -> void:
	model.position-=death_lift;death_lift=Vector3.ZERO
	if dead and blend_remaining>0. and not support_skin.is_empty():
		var normal: Vector3=(model.global_basis.orthonormalized()*source_model_basis.inverse()*Vector3.UP).normalized()
		var gap:=Ground.minimum_plane_gap(support_skin,skeleton,skeleton.global_transform,model.global_position,normal)
		if gap<0.:
			var before:=model.position;model.global_position+=normal*(-gap+.00005);death_lift=model.position-before
	update_landmarks()
func _process(delta: float) -> void:
	blend_remaining=maxf(0.,blend_remaining-delta*minf(1.,minf(absf(animator.speed_scale),absf(animator.get_playing_speed()))))
	super._process(delta)
func set_hue(value: int) -> void:
	if model!=null and treatment!="original" and entry.has("pose_subdivision") and not model.has_meta("pose_subdivision"):
		var mesh: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
		model.set_meta("pose_subdivision",preload("res://Presentation/SourcePoseSubdivision.gd").apply(mesh,skeleton,int(entry.pose_subdivision.levels),float(entry.pose_subdivision.normal_offset_source_units)))
	super.set_hue(value)
	if model==null or treatment!="modern":return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source!=null:mesh.set_surface_override_material(surface,preload("res://Presentation/SourceAmorphousMaterial.gd").build(source,entry,value))
