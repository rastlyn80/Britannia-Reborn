extends "res://Presentation/SourceMageVisual.gd"
## Original Mummy rig/atlas, measured import residuals and exact-length legs.
var floor_curves: Dictionary={}
var death_entry_seconds:=0.
var death_entry_position:=Vector3.ZERO
func _ready() -> void:
	floor_curves=preload("res://Presentation/SourceGroundLookup.gd").load_curves(str(entry.ground_lookup),treatment)
	super._ready()
	contact.free();contact=preload("res://Presentation/SourceMummySupport.gd").new();skeleton.add_child(contact)
	contact.include_toe_descendants=true;contact.model_root=model;contact.flat_basis=source_model_basis.scaled_local(default_model_scale)
	contact.configure(model.find_children("*","MeshInstance3D",true,false)[0],false)
	contact.modification_processed.connect(update_landmarks);support_skin=contact.full_skin
	apply_blend_ground()
func apply_equipment_surface() -> void:
	# Mummy bandages belong to its original body, not the mage dye slots.
	pass
func apply_blend_ground() -> void:
	if floor_curves.is_empty() or support_skin.is_empty() or animator.assigned_animation.is_empty():return
	var time:=animator.current_animation_position
	if death_entry_seconds>0. and animator.assigned_animation=="Death":
		if time<=0.:
			model.position=death_entry_position;contact.base_model_y=model.position.y;update_landmarks();return
		time=maxf(0.,time-death_entry_seconds)
	var curve:=preload("res://Presentation/SourceGroundLookup.gd").sample(floor_curves,animator.assigned_animation,time)
	model.position.y=source_model_position.y+curve
	if blend_remaining>0.:
		var normal: Vector3=(model.basis.orthonormalized()*source_model_basis.inverse()*Vector3.UP).normalized()
		var origin:=Vector3.ZERO
		if contact!=null and contact.contacts.has(0):
			var hit: Dictionary=contact.contacts[0];origin=to_local(hit.position);normal=(global_basis.inverse()*hit.normal).normalized()
		var space:=global_transform.affine_inverse()*skeleton.global_transform
		var gap:=preload("res://Presentation/SourceGroundLookup.gd").minimum_plane_gap(support_skin,skeleton,space,origin,normal)
		model.position.y-=gap/maxf(.75,normal.y)
	contact.base_model_y=model.position.y
	# Reference lift is measured without model translation. Include the same
	# residual so stance IK cannot reinterpret import interpolation as a hop.
	if contact.get_script()==preload("res://Presentation/SourceMummySupport.gd"):
		contact.residual_height=model.position.y-source_model_position.y
	update_landmarks()
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	apply_blend_ground()
func begin_death_from(source: Node3D) -> float:
	# A private clip enters from the displayed source pose, including terrain IK.
	# Source keys retain their timing after the short entry; shared art is intact.
	death_entry_seconds=.08;death_entry_position=source.model.position
	var original: Animation=animator.get_animation("Death");var animation:=original.duplicate(true) as Animation
	animation.length=original.length+death_entry_seconds
	var source_rig: Skeleton3D=source.skeleton
	for track in animation.get_track_count():
		for key in range(animation.track_get_key_count(track)-1,-1,-1):animation.track_set_key_time(track,key,animation.track_get_key_time(track,key)+death_entry_seconds)
		var path:=animation.track_get_path(track)
		if path.get_subname_count()==0:continue
		var bone:=source_rig.find_bone(str(path.get_subname(0)))
		if bone<0:continue
		if animation.track_get_type(track)==Animation.TYPE_POSITION_3D:animation.position_track_insert_key(track,0.,source_rig.get_bone_pose_position(bone))
		elif animation.track_get_type(track)==Animation.TYPE_ROTATION_3D:animation.rotation_track_insert_key(track,0.,source_rig.get_bone_pose_rotation(bone))
		elif animation.track_get_type(track)==Animation.TYPE_SCALE_3D:animation.scale_track_insert_key(track,0.,source_rig.get_bone_pose_scale(bone))
	var library: AnimationLibrary=animator.get_animation_library("").duplicate()
	animator.stop(true);animator.remove_animation_library("");animator.add_animation_library("",library);library.remove_animation("Death");library.add_animation("Death",animation)
	current_clip="Death";dead=true;action_remaining=animation.length;contact.enabled=false;blend_remaining=death_entry_seconds+.04
	animator.speed_scale=1.;animator.play("Death",0.);animator.seek(0.,true)
	return animation.length
