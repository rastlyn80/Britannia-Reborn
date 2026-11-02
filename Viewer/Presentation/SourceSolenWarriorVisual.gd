extends "res://Presentation/SourceSolenVisual.gd"
## Original eight-slot warrior skins. Worker support/materials stay unchanged.
signal landmarks_changed
var model_anchor:=Vector3.ZERO
var death_entry_seconds:=0.
var death_entry_position:=Vector3.ZERO
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
	var time:=animator.current_animation_position
	var entering:=death_entry_seconds>0. and animator.assigned_animation=="Death"
	if entering and time<=0.:
		model.position=death_entry_position;contact.residual_height=model.position.y-model_anchor.y;update_landmarks();return
	var source_time:=maxf(0.,time-death_entry_seconds) if entering else time
	var calibrated:=model_anchor+Vector3.UP*Ground.sample(ground_curves,animator.assigned_animation,source_time)
	model.position=death_entry_position.lerp(calibrated,clampf(time/death_entry_seconds,0.,1.)) if entering else calibrated
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
func begin_death_from(source: Node3D) -> float:
	# Sample the original target before building private entry tracks for all
	# bones and the separate source placement node, including omitted channels.
	var displayed_position: Vector3=source.model.position
	var source_rig: Skeleton3D=source.skeleton
	var displayed_space: Transform3D=source.source_space.transform
	animator.stop();animator.speed_scale=1.;play("Death",0.);animator.seek(0.,true);animator.advance(0.);skeleton.force_update_all_bone_transforms()
	var path:=animator.get_node(animator.root_node).get_path_to(source_space)
	var animation:=preload("res://Presentation/SourcePoseEntry.gd").build(animator,skeleton,source_rig,{path:displayed_space})
	var library:=animator.get_animation_library("").duplicate()
	animator.stop(true);animator.remove_animation_library("");animator.add_animation_library("",library);library.remove_animation("Death");library.add_animation("Death",animation)
	death_entry_seconds=.08;death_entry_position=displayed_position
	current_clip="Death";dead=true;action_remaining=animation.length;contact.enabled=false;blend_remaining=death_entry_seconds+.04
	animator.speed_scale=1.;animator.play("Death",0.);animator.seek(0.,true);animator.advance(0.)
	return animation.length
