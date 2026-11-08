extends "res://Presentation/CreatureVisual.gd"
## The new gestures use the complete stone skin instead of the single leg chain.

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const GESTURES := ["CopperRecoil", "CopperBrace", "CopperShift"]
var skin: Dictionary
var gesture_model := Transform3D.IDENTITY
var gesture_adjusted := false

func _ready() -> void:
	super._ready()
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	skin = Ground.skin_points(mesh, skeleton)
	animator.mixer_applied.connect(support_gesture)

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	restore_gesture()
	if current_clip in GESTURES:
		contact.enabled = false
	return true

func _physics_process(delta: float) -> void:
	if current_clip not in GESTURES:
		restore_gesture()
		super._physics_process(delta)

func restore_gesture() -> void:
	if gesture_adjusted:
		model.transform = gesture_model
		gesture_adjusted = false

func support_gesture() -> void:
	restore_gesture()
	if current_clip not in GESTURES:
		return
	var origin := global_position
	var ray := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.7, origin - Vector3.UP * 3.0, 1)
	var plane := get_world_3d().direct_space_state.intersect_ray(ray)
	if plane.is_empty() or plane.normal.y < 0.75:
		return
	gesture_model = model.transform
	gesture_adjusted = true
	var normal: Vector3 = plane.normal
	var local_normal := (global_basis.inverse() * normal).normalized()
	model.basis = Basis(Quaternion(Vector3.UP, local_normal)) * gesture_model.basis
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(skin, skeleton, skeleton.global_transform, plane.position, normal)
	model.global_position.y += (0.003 - gap) / normal.y
