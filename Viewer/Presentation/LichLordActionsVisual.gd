extends "res://Presentation/LichActionsVisual.gd"
## Retain the Lord's accent and support the complete robe during fitted gestures.

var gesture_lift := 0.0
var gesture_skin: Dictionary

func _ready() -> void:
	super._ready()
	gesture_skin = Ground.skin_points(body_mesh, skeleton)
	animator.mixer_applied.connect(settle_lord_gesture)
	contact.modification_processed.connect(settle_lord_gesture)

func _physics_process(delta: float) -> void:
	release_lord_gesture()
	super._physics_process(delta)

func receive_action(request: Dictionary) -> bool:
	release_lord_gesture()
	return super.receive_action(request)

func release_lord_gesture() -> void:
	if gesture_lift > 0.0:
		model.global_position.y -= gesture_lift
		gesture_lift = 0.0

func settle_lord_gesture() -> void:
	release_lord_gesture()
	if dead or current_clip not in entry.grounded_gestures:
		return
	var plane := support_plane(self)
	var normal: Vector3 = plane.normal
	if normal.y <= 0.75:
		return
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(gesture_skin, skeleton, skeleton.global_transform, plane.position, normal)
	gesture_lift = maxf(0.0, (0.003 - gap) / normal.y)
	model.global_position.y += gesture_lift
	update_grip()

func begin_death_from(source: Node3D) -> float:
	model.global_position.y -= source.gesture_lift
	return super.begin_death_from(source)

func set_hue(value: int) -> void:
	super.set_hue(value)
	if treatment != "modern" or body_mesh == null:
		return
	for surface in body_mesh.mesh.get_surface_count():
		var material := body_mesh.get_surface_override_material(surface) as ShaderMaterial
		if material != null:
			material.set_shader_parameter("use_accent", true)
