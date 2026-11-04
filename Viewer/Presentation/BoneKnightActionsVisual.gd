extends "res://Presentation/SourceHeldPropsVisual.gd"
## Clear shallow intersections from the new living gestures after foot support.

const MAX_GESTURE_LIFT := 0.06
var gesture_skins: Array[Dictionary] = []
var gesture_lift := 0.0

func _ready() -> void:
	super._ready()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			gesture_skins.append(Ground.skin_points(mesh, skeleton))
	contact.modification_processed.connect(clear_gesture_ground)

func _physics_process(delta: float) -> void:
	release_gesture_lift()
	super._physics_process(delta)

func release_gesture_lift() -> void:
	if gesture_lift > 0.0:
		model.global_position.y -= gesture_lift
		gesture_lift = 0.0

func clear_gesture_ground() -> void:
	release_gesture_lift()
	if dead or current_clip not in entry.grounded_gestures or contact.contacts.is_empty():
		return
	var hit: Dictionary = contact.contacts.values()[0]
	var normal: Vector3 = hit.normal
	var gap := INF
	for skin: Dictionary in gesture_skins:
		gap = minf(gap, Ground.minimum_plane_gap(skin, skeleton, skeleton.global_transform, hit.position, normal))
	gesture_lift = clampf((CLEARANCE - gap) / normal.y, 0.0, MAX_GESTURE_LIFT)
	model.global_position.y += gesture_lift
