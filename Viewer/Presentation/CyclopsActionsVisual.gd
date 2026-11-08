extends "res://Presentation/SourceHeldPropsVisual.gd"
## Keep the recovered mallet attached and clear of the ground through both falls.

const GROUNDED := ["Attack", "MalletSideSweep", "MalletLunge", "MalletHighBrace", "MalletRearBrace", "MalletCheck"]
var fall := preload("res://Presentation/SourceSpaceFallPlayback.gd").new()
var body_skin: Dictionary
var mallet_skin: Dictionary
var mallet_shift := Vector3.ZERO
var gesture_model := Transform3D.IDENTITY
var gesture_adjusted := false

func _ready() -> void:
	super._ready()
	body_skin = Ground.skin_points(model.find_child("Body", true, false), skeleton)
	mallet_skin = Ground.skin_points(model.find_child("CyclopsMallet", true, false), skeleton)
	animator.mixer_applied.connect(settle)

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	restore_gesture()
	clear_mallet_shift()
	fall.accept_action(self)
	if current_clip in GROUNDED:
		contact.enabled = false
	return true

func _physics_process(delta: float) -> void:
	if (dead and fall.plane.is_empty()) or (not dead and current_clip not in GROUNDED):
		super._physics_process(delta)

func begin_death_from(source: Node3D) -> float:
	if not source.gesture_adjusted and (not source.dead or source.fall.plane.is_empty()):
		return super.begin_death_from(source)
	var remaining := fall.begin_from_source(self, source, source.fall, source.mallet_shift)
	support_fall()
	return remaining

func settle() -> void:
	restore_gesture()
	clear_mallet_shift()
	if dead and not fall.plane.is_empty():
		fall.settle(self)
		support_fall()
	elif not dead and current_clip in GROUNDED:
		var plane := fall.floor_under(self)
		if plane.has("collider"):
			gesture_model = model.transform
			gesture_adjusted = true
			var normal: Vector3 = plane.normal
			var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
			model.basis = (slope * source_model_basis).scaled_local(gesture_model.basis.get_scale())
			skeleton.force_update_all_bone_transforms()
			var gap := minf(Ground.minimum_plane_gap(body_skin, skeleton, skeleton.global_transform, plane.position, normal),
				Ground.minimum_plane_gap(mallet_skin, skeleton, skeleton.global_transform, plane.position, normal))
			model.global_position.y += (0.003 - gap) / normal.y
			raise_over_steps(plane)

func restore_gesture() -> void:
	if gesture_adjusted:
		model.transform = gesture_model
		gesture_adjusted = false

func clear_mallet_shift() -> void:
	if mallet_shift != Vector3.ZERO:
		model.position -= mallet_shift
		mallet_shift = Vector3.ZERO

func support_mallet(plane: Dictionary, clearance: float) -> void:
	clear_mallet_shift()
	var normal: Vector3 = plane.normal
	var gap := Ground.minimum_plane_gap(mallet_skin, skeleton, skeleton.global_transform, plane.position, normal)
	var before := model.position
	model.global_position.y += maxf(0.0, (clearance - gap) / normal.y)
	mallet_shift = model.position - before

func support_fall() -> void:
	support_mallet(fall.plane, 0.002)
	if not fall.plane.has("collider"):
		return
	var before := model.position
	raise_over_steps(fall.plane)
	mallet_shift += model.position - before

func raise_over_steps(plane: Dictionary) -> void:
	if death_skin.is_empty():
		death_skin.assign([body_skin, mallet_skin])
	var floor_y: float = plane.position.y
	var query := PhysicsRayQueryParameters3D.create(Vector3.UP, Vector3.ZERO, 1)
	model.global_position.y += surface_lift(floor_y, query)

func corpse_snapshot_floor() -> float:
	if fall.plane.is_empty():
		return super.corpse_snapshot_floor()
	support_fall()
	var local := global_transform.affine_inverse() * skeleton.global_transform
	return minf(fall.snapshot_floor(self), Ground.minimum_plane_gap(mallet_skin, skeleton, local, Vector3.ZERO, Vector3.UP))
