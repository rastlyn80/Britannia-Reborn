extends "res://Presentation/CreatureVisual.gd"
## Terrain correction for the armed collapse. The native root stays fixed.

const CLEARANCE := 0.003
const MAX_STEP := 0.65
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
var death_model: Transform3D
var death_skin: Array[Dictionary] = []

func begin_death_from(_source: Node3D) -> float:
	death_model = model.transform
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			death_skin.append(Ground.skin_points(mesh, skeleton))
	play("Death", 0.08)
	set_physics_process(true)
	return animator.get_animation("Death").length

func _physics_process(delta: float) -> void:
	if not dead:
		super._physics_process(delta)
	elif not death_skin.is_empty():
		support_collapse()

func support_collapse() -> void:
	model.transform = death_model
	var up := Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(global_position + up * 2.0, global_position - up * 2.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var normal: Vector3 = hit.normal
	if normal.y < 0.8:
		return
	skeleton.force_update_all_bone_transforms()
	var lift := surface_lift(float(hit.position.y), query)
	model.position += global_basis.inverse() * (up * lift)

func surface_lift(root_floor: float, query: PhysicsRayQueryParameters3D) -> float:
	# A nearby riser can be under the body or weapon while the center ray is
	# still on the lower surface. Only probe vertices below the local ceiling.
	var lift := 0.0
	var ceiling := root_floor + MAX_STEP
	var world := get_world_3d().direct_space_state
	for skin in death_skin:
		var transforms: Array[Transform3D] = []
		for i in skin.bones.size():
			transforms.append(skeleton.global_transform * skeleton.get_bone_global_pose(skin.bones[i]) * skin.bind_poses[i])
		for surface: Dictionary in skin.surfaces:
			var points: PackedVector3Array = surface.points
			var bindings: PackedInt32Array = surface.bindings
			var weights: PackedFloat32Array = surface.weights
			var stride: int = surface.stride
			for vertex in points.size():
				var point := Vector3.ZERO
				for slot in stride:
					var index := vertex * stride + slot
					var weight := weights[index]
					if weight > 0.0:
						point += (transforms[bindings[index]] * points[vertex]) * weight
				if point.y + lift >= ceiling + CLEARANCE:
					continue
				query.from = Vector3(point.x, ceiling, point.z)
				query.to = Vector3(point.x, root_floor - MAX_STEP, point.z)
				var hit := world.intersect_ray(query)
				if not hit.is_empty() and hit.normal.y >= 0.8:
					lift = maxf(lift, float(hit.position.y) + CLEARANCE / float(hit.normal.y) - point.y)
	return lift

func minimum_gap(space: Transform3D, origin: Vector3, normal: Vector3) -> float:
	var gap := INF
	for skin in death_skin:
		gap = minf(gap, Ground.minimum_plane_gap(skin, skeleton, space, origin, normal))
	return gap

func corpse_snapshot_floor() -> float:
	support_collapse()
	return minimum_gap(global_transform.affine_inverse() * skeleton.global_transform, Vector3.ZERO, Vector3.UP)
