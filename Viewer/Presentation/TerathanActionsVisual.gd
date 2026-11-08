extends "res://Presentation/CreatureVisual.gd"

const Fall := preload("res://Presentation/SourceSpaceFallPlayback.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
var fall := Fall.new()
var skin: Dictionary
var gesture_pose := Transform3D.IDENTITY
var gesture_supported := false

func _ready() -> void:
	super._ready()
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	skin = Ground.skin_points(mesh, skeleton)
	animator.mixer_applied.connect(settle)

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	restore_gesture()
	fall.accept_action(self)
	if current_clip in entry.grounded_gestures:
		contact.enabled = false
	return true

func _physics_process(delta: float) -> void:
	if not dead and current_clip not in entry.grounded_gestures:
		super._physics_process(delta)

func begin_death_from(source: Node3D) -> float:
	return fall.begin_from_source(self, source, source.fall)

func settle() -> void:
	restore_gesture()
	if dead and not fall.plane.is_empty():
		fall.settle(self)
	elif current_clip in entry.grounded_gestures:
		var support := fall.floor_under(self)
		var normal: Vector3 = support.normal
		gesture_pose = model.transform
		gesture_supported = true
		var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
		model.basis = (slope * source_model_basis).scaled_local(gesture_pose.basis.get_scale())
		skeleton.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(skin, skeleton, skeleton.global_transform, support.position, normal)
		model.global_position.y += (0.003 - gap) / normal.y

func restore_gesture() -> void:
	if gesture_supported:
		model.transform = gesture_pose
		gesture_supported = false

func corpse_snapshot_floor() -> float:
	return INF if fall.plane.is_empty() else fall.snapshot_floor(self)
