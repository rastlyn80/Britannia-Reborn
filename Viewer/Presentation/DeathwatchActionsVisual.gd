extends "res://Presentation/AlternateCollapseVisual.gd"
## Ground explicit reactions and either fall on the retained beetle skin.

const GROUNDED_REACTIONS := ["Hit", "Fidget", "LeftRecoil", "RightRecoil", "RearingFidget"]
const MAX_REACTION_LIFT := 0.18

func begin_death_from(source: Node3D) -> float:
	if not source.dead or source.current_clip != "Death2":
		model.position -= source.collapse_shift
	return super.begin_death_from(source)

func settle_collapse() -> void:
	super.settle_collapse()
	if dead or current_clip not in GROUNDED_REACTIONS:
		return
	collapse_plane = {}
	sample_collapse_ground()
	if not collapse_plane.has("collider"):
		return
	if collapse_skin.is_empty():
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		collapse_skin = Ground.skin_points(mesh, skeleton)
	skeleton.force_update_all_bone_transforms()
	var normal: Vector3 = collapse_plane.normal
	var gap := Ground.minimum_plane_gap(collapse_skin, skeleton, skeleton.global_transform,
		collapse_plane.position, normal)
	var prior := model.position
	model.global_position += normal * clampf(0.003 - gap, 0.0, MAX_REACTION_LIFT)
	collapse_shift = model.position - prior
