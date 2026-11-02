extends "res://Presentation/MeasuredCreatureVisual.gd"
## Original elemental skin/rig, measured source lift and authored frost surface.
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
var support_skin: Dictionary={}
var blend_remaining:=0.
var death_lift:=Vector3.ZERO
func _ready() -> void:
	super._ready()
	contact.free();contact=preload("res://Presentation/SourcePlaneSoleSupport.gd").new();skeleton.add_child(contact);contact.include_toe_descendants=true;contact.model_root=model;contact.flat_basis=source_model_basis.scaled_local(default_model_scale);contact.configure(model.find_children("*","MeshInstance3D",true,false)[0],false);contact.modification_processed.connect(update_landmarks)
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
	# Remove only our previous compensation; retain the live terrain adapter's
	# own placement. During death that adapter is disabled, so its last plane
	# is represented by the retained model basis and uncorrected model origin.
	model.position-=death_lift;death_lift=Vector3.ZERO
	if dead and blend_remaining>0. and not support_skin.is_empty():
		var normal: Vector3=(model.global_basis.orthonormalized()*source_model_basis.inverse()*Vector3.UP).normalized()
		var gap:=Ground.minimum_plane_gap(support_skin,skeleton,skeleton.global_transform,model.global_position,normal)
		if gap<0.:
			var before:=model.position;model.global_position+=normal*(-gap+.00005);death_lift=model.position-before
	update_landmarks()
func _process(delta: float) -> void:
	var clock:=minf(1.,minf(absf(animator.speed_scale),absf(animator.get_playing_speed())))
	blend_remaining=maxf(0.,blend_remaining-delta*clock)
	super._process(delta)
func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null or treatment!="modern":return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source!=null:mesh.set_surface_override_material(surface,preload("res://Presentation/SourceElementalMaterial.gd").build(source,entry,value))
