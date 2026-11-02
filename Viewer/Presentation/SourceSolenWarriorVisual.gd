extends "res://Presentation/SourceSolenVisual.gd"
## Original eight-slot warrior skins. Worker support/materials stay unchanged.
signal landmarks_changed
var model_anchor:=Vector3.ZERO
func update_landmarks() -> void:
	super.update_landmarks()
	if not influence_bounds.is_empty():landmarks_changed.emit()
func _ready() -> void:
	super._ready()
	# Replace the worker's Attack2-only source-space correction with this
	# candidate's per-action model correction and constant gait anchors.
	for connection: Dictionary in animator.mixer_applied.get_connections():
		var callback: Callable=connection.callable
		if callback.get_method()==&"support_death_blend":animator.mixer_applied.disconnect(callback)
	# Constant tracks may be omitted during import. Restore unkeyed bones to
	# their source rest instead of retaining a preceding action's rotation.
	animator.deterministic=true
	contact.free();contact=preload("res://Presentation/SourceSolenWarriorSupport.gd").new();skeleton.add_child(contact)
	contact.model_root=model;contact.flat_basis=source_model_basis.scaled_local(default_model_scale);contact.animator=animator
	contact.configure(model.find_children("*","MeshInstance3D",true,false)[0],false);contact.modification_processed.connect(update_landmarks)
	model_anchor=model.position
	animator.mixer_applied.connect(apply_warrior_ground)
	apply_warrior_ground()
func apply_warrior_ground() -> void:
	if source_space==null or ground_curves.is_empty() or animator.assigned_animation.is_empty():return
	model.position=model_anchor
	model.position.y+=Ground.sample(ground_curves,animator.assigned_animation,animator.current_animation_position)
	# Support only negative mixed-pose clearance. Positive source flight
	# survives instead of being flattened during a crossfade.
	if blend_remaining>0. and not support_skin.is_empty():
		var normal: Vector3=(model.basis.orthonormalized()*source_model_basis.inverse()*Vector3.UP).normalized();var origin:=Vector3.ZERO
		if contact.contacts.has(0):
			var hit: Dictionary=contact.contacts[0];origin=to_local(hit.position);normal=(global_basis.inverse()*hit.normal).normalized()
		var space:=global_transform.affine_inverse()*skeleton.global_transform
		var gap:=Ground.minimum_plane_gap(support_skin,skeleton,space,origin,normal)
		if gap<0.:model.position.y+=(-gap+.00005)/maxf(.75,normal.y)
	contact.residual_height=model.position.y-model_anchor.y
	update_landmarks()
