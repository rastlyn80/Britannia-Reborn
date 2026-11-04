extends "res://Presentation/CreatureVisual.gd"
## Clears shallow terrain intersections during explicitly reviewed gestures.

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const MAX_LIFT := 0.08

static var source_skins: Dictionary = {}
var reference_skin: Dictionary
var gesture_lift := 0.0

func _ready() -> void:
	super._ready()
	var path: String = entry.classic_gesture_base_assets.original
	if not source_skins.has(path):
		var reference := (load(path) as PackedScene).instantiate()
		var mesh := reference.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		source_skins[path] = Ground.skin_points(mesh, skeleton)
		reference.free()
	reference_skin = source_skins[path]
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
	if current_clip not in entry.grounded_gestures or contact.contacts.is_empty():
		return
	var hit: Dictionary = contact.contacts.values()[0]
	var normal: Vector3 = hit.normal
	if normal.y < 0.5:
		return
	var gap := Ground.minimum_plane_gap(reference_skin, skeleton, skeleton.global_transform, hit.position, normal)
	gesture_lift = clampf((0.003 - gap) / normal.y, 0.0, MAX_LIFT)
	model.global_position.y += gesture_lift
