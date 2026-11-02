extends "res://Presentation/MeasuredCreatureVisual.gd"
## Original integral costume, with independent server garment/body colours.
## A removed item restores the base costume; it cannot remove source geometry.
signal landmarks_changed
var server_equipment: Array=[]
var equipment_surface_key:=""
var blend_remaining:=0.
var source_model_position:=Vector3.ZERO
var support_skin: Dictionary={}
func update_landmarks() -> void:
	super.update_landmarks()
	if not influence_bounds.is_empty():landmarks_changed.emit()
func _ready() -> void:
	super._ready()
	contact.free();contact=preload("res://Presentation/SourceMageSupport.gd").new();skeleton.add_child(contact)
	contact.include_toe_descendants=true;contact.model_root=model;contact.flat_basis=source_model_basis.scaled_local(default_model_scale)
	contact.configure(model.find_children("*","MeshInstance3D",true,false)[0],false)
	contact.modification_processed.connect(update_landmarks)
	source_model_position=model.position
	support_skin=contact.full_skin
	animator.mixer_applied.connect(apply_blend_ground)
func play(clip: String,blend: float=.12) -> void:
	blend_remaining=blend+.04 if blend>0. else 0.
	super.play(clip,blend)
func receive_action(request: Dictionary) -> bool:
	var accepted:=super.receive_action(request)
	if accepted:blend_remaining=maxf(blend_remaining,.16)
	return accepted
func _process(delta: float) -> void:
	var clock:=minf(1.,minf(absf(animator.speed_scale),absf(animator.get_playing_speed())))
	blend_remaining=maxf(0.,blend_remaining-delta*clock)
	super._process(delta)
func apply_blend_ground() -> void:
	if support_skin.is_empty():return
	model.position.y=source_model_position.y
	if blend_remaining>0.:
		var origin:=Vector3.ZERO
		# Death releases living contacts. Its copied terrain tilt still defines
		# the plane through the actor's grounded presentation anchor.
		var normal: Vector3=(model.basis.orthonormalized()*source_model_basis.inverse()*Vector3.UP).normalized()
		if contact!=null and contact.contacts.has(0):
			var hit: Dictionary=contact.contacts[0];origin=to_local(hit.position);normal=(global_basis.inverse()*hit.normal).normalized()
		var space:=global_transform.affine_inverse()*skeleton.global_transform
		var gap:=preload("res://Presentation/SourceGroundLookup.gd").minimum_plane_gap(support_skin,skeleton,space,origin,normal)
		model.position.y-=gap/maxf(.75,normal.y)
	contact.base_model_y=model.position.y
	update_landmarks()
func set_hue(value: int) -> void:
	super.set_hue(value)
	equipment_surface_key=""
	apply_equipment_surface()
func set_equipment(worn: Array) -> void:
	server_equipment=worn.duplicate(true)
	apply_equipment_surface()
func apply_equipment_surface() -> void:
	if model==null or treatment!="modern":return
	var slots:=preload("res://Presentation/SourceMageMaterial.gd").slots(server_equipment)
	var key:=JSON.stringify([hue,detail,slots])
	if key==equipment_surface_key:return
	equipment_surface_key=key
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source!=null:mesh.set_surface_override_material(surface,preload("res://Presentation/SourceMageMaterial.gd").build(source,hue,slots,detail))
