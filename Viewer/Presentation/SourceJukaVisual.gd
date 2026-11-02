extends "res://Presentation/SourceMageVisual.gd"
## Reuse measured source-leg/blend support; Juka has no mage costume dye slots.
func _ready() -> void:
	super._ready()
	contact.free();contact=preload("res://Presentation/SourceJukaSupport.gd").new();skeleton.add_child(contact)
	contact.include_toe_descendants=true;contact.model_root=model;contact.flat_basis=source_model_basis.scaled_local(default_model_scale)
	contact.configure(model.find_children("*","MeshInstance3D",true,false)[0],false)
	contact.modification_processed.connect(update_landmarks);support_skin=contact.full_skin
func apply_equipment_surface() -> void:
	pass
func apply_blend_ground() -> void:
	super.apply_blend_ground()
	if support_skin.is_empty():return
	var airborne:=0.
	if blend_remaining>0. and not dead and contact.has_method("source_airborne_height"):airborne=contact.source_airborne_height()
	if airborne<=0. and (blend_remaining>0. or animator.current_animation!="Death2"):return
	# The fast forward collapse changes its lowest surface between baked keys.
	# Ground the complete dying skin without changing source joints or native XYZ.
	var origin:=Vector3.ZERO
	var normal: Vector3=(model.basis.orthonormalized()*source_model_basis.inverse()*Vector3.UP).normalized()
	if contact!=null and contact.contacts.has(0):
		var hit: Dictionary=contact.contacts[0];origin=to_local(hit.position);normal=(global_basis.inverse()*hit.normal).normalized()
	if airborne>0.:
		model.position.y+=airborne/maxf(.75,normal.y)
	else:
		var space:=global_transform.affine_inverse()*skeleton.global_transform
		var gap:=preload("res://Presentation/SourceGroundLookup.gd").minimum_plane_gap(support_skin,skeleton,space,origin,normal)
		model.position.y-=gap/maxf(.75,normal.y)
	contact.base_model_y=model.position.y
	update_landmarks()
