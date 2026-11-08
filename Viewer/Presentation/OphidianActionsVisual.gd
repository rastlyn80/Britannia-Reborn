extends "res://Presentation/SourceArmedLizardmanVisual.gd"
## Apply corpse support to both the original body and its skinned bardiche.

const GROUNDED := ["BardicheLowSweep", "BardicheHighChop", "BardicheHighRecoil", "BardicheLowBrace", "BardicheGripShift"]
var fall := preload("res://Presentation/CreatureFallPlayback.gd").new()
var bardiche_skin: Dictionary
var body_skin: Dictionary
var bardiche_shift := Vector3.ZERO
var gesture_model := Transform3D.IDENTITY
var gesture_adjusted := false

func _ready() -> void:
	super._ready()
	var blade := model.find_child("OphidianBardiche", true, false) as MeshInstance3D
	bardiche_skin = Ground.skin_points(blade, skeleton)
	var body_mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	body_skin = Ground.skin_points(body_mesh, skeleton)
	animator.mixer_applied.connect(settle_armed_fall)

func receive_action(request: Dictionary) -> bool:
	restore_gesture()
	model.position -= bardiche_shift
	bardiche_shift = Vector3.ZERO
	if not super.receive_action(request):
		return false
	fall.accept_action(self)
	return true

func begin_death_from(source: Node3D) -> float:
	if source.gesture_adjusted:
		model.transform = source.gesture_model
	if not source.dead or source.fall.plane.is_empty():
		# The ordinary server kill still uses the original per-vertex step support.
		return super.begin_death_from(source)
	model.position -= source.bardiche_shift
	var remaining := fall.begin_from(self, source, source.fall)
	if not fall.blend_pose.is_empty():
		# SourceSpace has its own vertical track in the recovered collapse.
		var rig_root := skeleton.find_bone("__root")
		assert(rig_root >= 0 and skeleton.get_bone_parent(rig_root) < 0)
		var root_pose: Transform3D = fall.blend_pose[rig_root]
		var unshifted_origin := skeleton.global_position - global_basis * fall.shift
		root_pose.origin += skeleton.global_basis.inverse() * (source.skeleton.global_position - unshifted_origin)
		fall.blend_pose[rig_root] = root_pose
		fall.settle(self)
	support_bardiche()
	return remaining

func settle_armed_fall() -> void:
	restore_gesture()
	model.position -= bardiche_shift
	bardiche_shift = Vector3.ZERO
	fall.settle(self)
	support_bardiche()
	if not dead and current_clip in GROUNDED:
		fit_grounded_gesture()

func restore_gesture() -> void:
	if gesture_adjusted:
		model.transform = gesture_model
		gesture_adjusted = false

func fit_grounded_gesture() -> void:
	var plane: Dictionary = fall.floor_under(self)
	if not plane.has("collider"):
		return
	gesture_model = model.transform
	gesture_adjusted = true
	var normal: Vector3 = plane.normal
	var local_normal := (global_basis.inverse() * normal).normalized()
	model.basis = Basis(Quaternion(Vector3.UP, local_normal)) * gesture_model.basis
	skeleton.force_update_all_bone_transforms()
	var gap := INF
	for skin: Dictionary in [body_skin, bardiche_skin]:
		gap = minf(gap, Ground.minimum_plane_gap(skin, skeleton, skeleton.global_transform, plane.position, normal))
	model.global_position.y += (0.003 - gap) / normal.y

func support_bardiche() -> void:
	model.position -= bardiche_shift
	bardiche_shift = Vector3.ZERO
	if not dead or fall.plane.is_empty():
		return
	var normal: Vector3 = fall.plane.normal
	var gap := Ground.minimum_plane_gap(bardiche_skin, skeleton, skeleton.global_transform, fall.plane.position, normal)
	var before := model.position
	model.global_position.y += maxf(0.0, (0.002 - gap) / normal.y)
	bardiche_shift = model.position - before

func corpse_snapshot_floor() -> float:
	if fall.plane.is_empty():
		return super.corpse_snapshot_floor()
	var local := global_transform.affine_inverse() * skeleton.global_transform
	return minf(fall.snapshot_floor(self), Ground.minimum_plane_gap(bardiche_skin, skeleton, local, Vector3.ZERO, Vector3.UP))
