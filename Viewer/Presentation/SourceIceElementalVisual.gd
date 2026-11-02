extends "res://Presentation/MeasuredCreatureVisual.gd"
## Opt-in Ice161 source body. Terrain support remains a separate validation gate.
signal landmarks_changed
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
var floor_curves: Dictionary={}
var support_skin: Dictionary={}
var model_anchor:=Vector3.ZERO
var blend_remaining:=0.
var death_entry_seconds:=0.
var death_entry_position:=Vector3.ZERO
var source_space: Node3D
func update_landmarks() -> void:
	super.update_landmarks()
	if not influence_bounds.is_empty():landmarks_changed.emit()
func _ready() -> void:
	floor_curves=Ground.load_curves(str(entry.ground_lookup),treatment)
	super._ready()
	animator.deterministic=true
	source_space=model.find_child("SourceSpace",true,false) as Node3D
	assert(source_space!=null)
	contact.free();contact=preload("res://Presentation/SourceIceElementalSupport.gd").new();skeleton.add_child(contact)
	contact.include_toe_descendants=true;contact.model_root=model;contact.flat_basis=source_model_basis.scaled_local(default_model_scale)
	contact.configure(model.find_children("*","MeshInstance3D",true,false)[0],false)
	contact.modification_processed.connect(update_landmarks)
	support_skin=contact.full_skin;model_anchor=model.position
	animator.mixer_applied.connect(apply_ice_ground)
	apply_ice_ground()
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
func apply_ice_ground() -> void:
	if floor_curves.is_empty() or support_skin.is_empty() or animator.assigned_animation.is_empty():return
	var time:=animator.current_animation_position
	var entering:=death_entry_seconds>0. and animator.assigned_animation=="Death"
	if entering and time<=0.:
		model.position=death_entry_position;contact.base_model_y=model.position.y;contact.residual_height=model.position.y-model_anchor.y;update_landmarks();return
	var source_time:=maxf(0.,time-death_entry_seconds) if entering else time
	var calibrated:=model_anchor+Vector3.UP*Ground.sample(floor_curves,animator.assigned_animation,source_time)
	model.position=death_entry_position.lerp(calibrated,clampf(time/death_entry_seconds,0.,1.)) if entering else calibrated
	# A blend may need positive support, but positive source flight is retained.
	if blend_remaining>0.:
		var normal: Vector3=(model.basis.orthonormalized()*source_model_basis.inverse()*Vector3.UP).normalized();var origin:=Vector3.ZERO
		if contact.contacts.has(0):
			var hit: Dictionary=contact.contacts[0];origin=to_local(hit.position);normal=(global_basis.inverse()*hit.normal).normalized()
		var space:=global_transform.affine_inverse()*skeleton.global_transform
		var gap:=Ground.minimum_plane_gap(support_skin,skeleton,space,origin,normal)
		if gap<0.:model.position.y+=(-gap+.00005)/maxf(.75,normal.y)
	contact.base_model_y=model.position.y;contact.residual_height=model.position.y-model_anchor.y
	update_landmarks()
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	apply_ice_ground()
func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null or treatment!="modern":return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source!=null:mesh.set_surface_override_material(surface,preload("res://Presentation/SourceIceElementalMaterial.gd").build(source,value,detail))
func begin_death_from(source: Node3D) -> float:
	var displayed_position: Vector3=source.model.position
	var displayed_space: Transform3D=source.source_space.transform
	animator.stop();animator.speed_scale=1.;play("Death",0.);animator.seek(0.,true);animator.advance(0.);skeleton.force_update_all_bone_transforms()
	var path:=animator.get_node(animator.root_node).get_path_to(source_space)
	var animation:=preload("res://Presentation/SourcePoseEntry.gd").build(animator,skeleton,source.skeleton,{path:displayed_space})
	var library:=animator.get_animation_library("").duplicate()
	animator.stop(true);animator.remove_animation_library("");animator.add_animation_library("",library);library.remove_animation("Death");library.add_animation("Death",animation)
	death_entry_seconds=.08;death_entry_position=displayed_position
	current_clip="Death";dead=true;action_remaining=animation.length;contact.enabled=false;blend_remaining=death_entry_seconds+.04
	animator.speed_scale=1.;animator.play("Death",0.);animator.seek(0.,true);animator.advance(0.)
	return animation.length
