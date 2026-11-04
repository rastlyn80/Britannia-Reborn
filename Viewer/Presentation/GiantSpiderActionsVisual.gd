extends "res://Presentation/SourceQuadrupedCollapseVisual.gd"
## The retained spider has no biped foot labels. Sample terrain under the body.

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead and not collapse_plane.has("collider"):
		sample_collapse_ground()
	return true

func begin_death_from(source: Node3D) -> float:
	var duration := super.begin_death_from(source)
	if not collapse_plane.has("collider"):
		sample_collapse_ground()
	return duration

func sample_collapse_ground() -> void:
	var origin := global_position
	var ray := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.7, origin - Vector3.UP * 1.6, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit.normal.y > 0.75:
		collapse_plane = hit
