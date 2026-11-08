extends "res://Presentation/SourceOphidianStaffVisual.gd"

const Fall := preload("res://Presentation/SourceSpaceFallPlayback.gd")
var fall := Fall.new()
var staff_skin: Dictionary
var staff_shift := Vector3.ZERO
var gesture_pose := Transform3D.IDENTITY
var gesture_supported := false

func _ready() -> void:
	super._ready()
	staff_skin = Ground.skin_points(model.find_child("OphidianMageStaff", true, false), skeleton)
	animator.mixer_applied.connect(settle)

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	restore_gesture()
	clear_staff_shift()
	fall.accept_action(self)
	if current_clip in entry.grounded_gestures:
		contact.enabled = false
	return true

func _physics_process(delta: float) -> void:
	if (dead and fall.plane.is_empty()) or (not dead and current_clip not in entry.grounded_gestures):
		super._physics_process(delta)

func _process(delta: float) -> void:
	super._process(delta)
	if current_clip == "StaffFlare" and not dead and action_remaining > 0.0:
		var phase := animator.current_animation_position / maxf(0.001, animator.current_animation_length)
		cast_sparks.emitting = phase >= 0.19 and phase < 0.59

func begin_death_from(source: Node3D) -> float:
	if not source.gesture_supported and (not source.dead or source.fall.plane.is_empty()):
		return super.begin_death_from(source)
	var remaining := fall.begin_from_source(self, source, source.fall, source.staff_shift)
	support_staff()
	return remaining

func settle() -> void:
	restore_gesture()
	clear_staff_shift()
	if dead and not fall.plane.is_empty():
		fall.settle(self)
		support_staff()
	elif current_clip in entry.grounded_gestures:
		var support := fall.floor_under(self)
		var normal: Vector3 = support.normal
		gesture_pose = model.transform
		gesture_supported = true
		var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
		model.basis = (slope * source_model_basis).scaled_local(gesture_pose.basis.get_scale())
		if fall.skin.is_empty():
			fall.skin = Ground.skin_points(model.find_children("*", "MeshInstance3D", true, false)[0], skeleton)
		skeleton.force_update_all_bone_transforms()
		var gap := minf(minimum_on_plane(fall.skin, support), minimum_on_plane(staff_skin, support))
		model.global_position.y += (0.003 - gap) / normal.y

func minimum_on_plane(skin: Dictionary, support: Dictionary) -> float:
	return Ground.minimum_plane_gap(skin, skeleton, skeleton.global_transform, support.position, support.normal)

func clear_staff_shift() -> void:
	if staff_shift != Vector3.ZERO:
		model.position -= staff_shift
		staff_shift = Vector3.ZERO

func support_staff() -> void:
	var gap := minimum_on_plane(staff_skin, fall.plane)
	var before := model.position
	model.global_position.y += maxf(0.0, (0.002 - gap) / float(fall.plane.normal.y))
	staff_shift = model.position - before

func restore_gesture() -> void:
	if gesture_supported:
		model.transform = gesture_pose
		gesture_supported = false

func corpse_snapshot_floor() -> float:
	if fall.plane.is_empty():
		return super.corpse_snapshot_floor()
	var space := global_transform.affine_inverse() * skeleton.global_transform
	return minf(fall.snapshot_floor(self), Ground.minimum_plane_gap(staff_skin, skeleton, space, Vector3.ZERO, Vector3.UP))
