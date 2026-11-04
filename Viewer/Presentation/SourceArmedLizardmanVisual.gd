extends "res://Presentation/CreatureVisual.gd"
## Terrain correction for the armed collapse. The native root stays fixed.

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
	var clearance := minimum_gap(skeleton.global_transform, hit.position, normal)
	var lift := maxf(0.0, (0.003 - clearance) / normal.y)
	model.position += global_basis.inverse() * (up * lift)

func minimum_gap(space: Transform3D, origin: Vector3, normal: Vector3) -> float:
	var gap := INF
	for skin in death_skin:
		gap = minf(gap, Ground.minimum_plane_gap(skin, skeleton, space, origin, normal))
	return gap

func corpse_snapshot_floor() -> float:
	support_collapse()
	return minimum_gap(global_transform.affine_inverse() * skeleton.global_transform, Vector3.ZERO, Vector3.UP)
