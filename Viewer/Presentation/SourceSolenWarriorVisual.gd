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
	model_anchor=model.position
	animator.mixer_applied.connect(apply_warrior_ground)
	apply_warrior_ground()
func apply_warrior_ground() -> void:
	if source_space==null or ground_curves.is_empty() or animator.assigned_animation.is_empty():return
	model.position=model_anchor
	model.position.y+=Ground.sample(ground_curves,animator.assigned_animation,animator.current_animation_position)
	# Correct the actual mixed collapse only during its short entry. Source
	# gait bounce and every original joint channel remain untouched.
	if dead and blend_remaining>0. and not support_skin.is_empty():
		var normal: Vector3=(model.global_basis.orthonormalized()*source_model_basis.inverse()*Vector3.UP).normalized()
		var gap:=Ground.minimum_plane_gap(support_skin,skeleton,skeleton.global_transform,model.global_position,normal)
		if gap<0.:model.global_position+=normal*(-gap+.00005)
	update_landmarks()
