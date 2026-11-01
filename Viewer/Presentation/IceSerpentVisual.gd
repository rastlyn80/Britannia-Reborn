extends "res://Presentation/SmallSnakeVisual.gd"
## Retained source skin with sampled grounding and its own cold cutout coat.
const Ground=preload("res://Presentation/SourceGroundLookup.gd")
var floor_curves: Dictionary={}
var source_position:=Vector3.ZERO
var blend_remaining:=0.
var support_skin: Dictionary={}
func _ready() -> void:
	super._ready()
	source_position=model.position
	floor_curves=Ground.load_curves(str(entry.ground_lookup),treatment)
	support_skin=Ground.skin_points(model.find_children("*","MeshInstance3D",true,false)[0],skeleton)
	animator.mixer_applied.connect(apply_ground)
	apply_ground()
func apply_ground() -> void:
	if floor_curves.is_empty() or animator.assigned_animation.is_empty():return
	model.position.y=source_position.y+Ground.sample(floor_curves,animator.assigned_animation,animator.current_animation_position)
	# A crossfade is not one of the individually measured poses. Evaluate its
	# unique skin points only during this short window; steady clips use curves.
	if blend_remaining>0. and not support_skin.is_empty():
		var origin:=Vector3.ZERO;var normal:=Vector3.UP
		if contact!=null and contact.contacts.has(0):
			var hit: Dictionary=contact.contacts[0];origin=to_local(hit.position);normal=(global_basis.inverse()*hit.normal).normalized()
		var space:=global_transform.affine_inverse()*skeleton.global_transform
		var gap:=Ground.minimum_plane_gap(support_skin,skeleton,space,origin,normal)
		model.position.y-=gap/maxf(.75,normal.y)
	update_landmarks()
func play(clip: String,blend: float=.12) -> void:
	blend_remaining=blend+.04 if blend>0. else 0.
	super.play(clip,blend)
func receive_action(request: Dictionary) -> bool:
	var accepted:=super.receive_action(request)
	if accepted:blend_remaining=maxf(blend_remaining,.16)
	return accepted
func _process(delta: float) -> void:
	# AnimationPlayer can stretch a blend when global/custom playback slows.
	var clock:=minf(1.,minf(absf(animator.speed_scale),absf(animator.get_playing_speed())))
	blend_remaining=maxf(0.,blend_remaining-delta*clock)
	super._process(delta)
func set_hue(value: int) -> void:
	super.set_hue(value)
	if model==null or treatment!="modern":return
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source:=mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source!=null:mesh.set_surface_override_material(surface,preload("res://Presentation/IceSerpentMaterial.gd").build(source,entry,value))
