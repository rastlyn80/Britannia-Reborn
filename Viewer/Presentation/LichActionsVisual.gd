extends "res://Presentation/LichVisual.gd"
## Settle the retained body and staff together through a native collapse.

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
var collapse_plane: Dictionary = {}
var collapse_skin: Dictionary = {}
var collapse_shift := Vector3.ZERO

func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(settle_collapse)

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		remember_floor(support_plane(self))
	else:
		collapse_plane = {}
	return true

func begin_death_from(source: Node3D) -> float:
	var continuing: bool = source.dead and source.current_clip == "Death2"
	model.position -= source.collapse_shift
	remember_floor(support_plane(source))
	current_clip = "Death2" if continuing else "Death"
	var elapsed: float = source.animator.current_animation_position if continuing else 0.0
	var speed: float = absf(source.animator.get_playing_speed()) if continuing else 1.0
	if is_zero_approx(speed):
		speed = 1.0
	animator.play(current_clip, 0.0 if continuing else 0.08, speed)
	if continuing:
		animator.advance(0.0)
		animator.seek(elapsed, true)
	action_remaining = maxf(0.0, animator.get_animation(current_clip).length - elapsed) / speed
	return action_remaining

func remember_floor(plane: Dictionary) -> void:
	collapse_plane = plane
	if collapse_skin.is_empty():
		collapse_skin = Ground.skin_points(body_mesh, skeleton)

func support_plane(source: Node3D) -> Dictionary:
	if source.collapse_plane.has("collider"):
		return source.collapse_plane
	if not source.contact.contacts.is_empty():
		return source.contact.contacts.values()[0]
	var origin := source.global_position
	var query := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.7, origin - Vector3.UP * 1.6, 1)
	var hit := source.get_world_3d().direct_space_state.intersect_ray(query)
	return hit if not hit.is_empty() and hit.normal.y > 0.75 else {"position": origin, "normal": Vector3.UP}

func support_normal() -> Vector3:
	return collapse_plane.normal if dead and not collapse_plane.is_empty() else super.support_normal()

func settle_collapse() -> void:
	model.position -= collapse_shift
	collapse_shift = Vector3.ZERO
	if not dead or collapse_plane.is_empty() or animator.current_animation_length <= 0.0:
		return
	var normal: Vector3 = collapse_plane.normal
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(collapse_skin, skeleton, skeleton.global_transform, collapse_plane.position, normal)
	var offset := 0.002 - gap
	if offset < 0.0:
		var phase := animator.current_animation_position / animator.current_animation_length
		offset *= smoothstep(0.75, 1.0, phase)
	var before := model.position
	model.global_position += normal * offset
	collapse_shift = model.position - before
	if staff != null:
		update_grip()
		# The original staff helper uses the model plane. The body may be
		# displaced during a collapse, so check the actual terrain as well.
		var staff_floor := staff_gap(staff.global_transform, normal)
		staff_floor += (model.global_position - collapse_plane.position).dot(normal)
		if staff_floor < 0.003:
			staff.global_position += normal * (0.003 - staff_floor)
			update_landmarks()

func corpse_snapshot_floor() -> float:
	skeleton.force_update_all_bone_transforms()
	var world_to_actor := global_transform.affine_inverse()
	var local_rig := world_to_actor * skeleton.global_transform
	var floor := Ground.minimum_plane_gap(collapse_skin, skeleton, local_rig, Vector3.ZERO, Vector3.UP)
	# Freezing normalizes against the lowest visible vertex, including the staff.
	for mesh: MeshInstance3D in staff_meshes():
		var local_staff := world_to_actor * mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point in vertices:
				floor = minf(floor, (local_staff * point).y)
	return floor
