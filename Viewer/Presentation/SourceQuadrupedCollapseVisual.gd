extends "res://Presentation/FieldClassicCollapseVisual.gd"
## Native death and explicit collapses share a grounded endpoint.

func begin_death_from(source: Node3D) -> float:
	var hit: Dictionary = source.contact.contacts.values()[0] if not source.contact.contacts.is_empty() else {}
	collapse_plane = hit if not hit.is_empty() else {"position": global_position, "normal": Vector3.UP}
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	collapse_skin = Ground.skin_points(mesh, skeleton)
	play("Death", 0.08)
	return animator.get_animation("Death").length

func corpse_snapshot_floor() -> float:
	skeleton.force_update_all_bone_transforms()
	var local_rig := global_transform.affine_inverse() * skeleton.global_transform
	return Ground.minimum_plane_gap(collapse_skin, skeleton, local_rig, Vector3.ZERO, Vector3.UP)
