extends "res://Presentation/VampireBatFallVisual.gd"
## Support the fitted gestures on spider rigs without named humanoid feet.

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const GESTURES := ["DreadReach", "DreadRock"]
const CLEARANCE := 0.003
var gesture_skin: Dictionary
var gesture_model := Transform3D.IDENTITY
var gesture_adjusted := false

func _ready() -> void:
	super._ready()
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	gesture_skin = Ground.skin_points(mesh, skeleton)
	animator.mixer_applied.connect(support_gesture)

func receive_action(request: Dictionary) -> bool:
	restore_gesture_model()
	return super.receive_action(request)

func begin_death_from(source: Node3D) -> float:
	if source.gesture_adjusted:
		model.transform = source.gesture_model
	return super.begin_death_from(source)

func restore_gesture_model() -> void:
	if gesture_adjusted:
		model.transform = gesture_model
		gesture_adjusted = false

func support_gesture() -> void:
	restore_gesture_model()
	if dead or current_clip not in GESTURES:
		return
	var hit: Dictionary = fall.floor_under(self)
	if not hit.has("collider"):
		return
	gesture_model = model.transform
	gesture_adjusted = true
	var normal: Vector3 = hit.normal
	var local_normal := (global_basis.inverse() * normal).normalized()
	model.basis = Basis(Quaternion(Vector3.UP, local_normal)) * gesture_model.basis
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(gesture_skin, skeleton, skeleton.global_transform, hit.position, normal)
	model.global_position.y += (CLEARANCE - gap) / normal.y
