extends "res://Presentation/GiantSpiderActionsVisual.gd"

var assembly_shift := Vector3.ZERO
var assembly_skin: Dictionary = {}

func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(adjust_assembly)

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	release_assembly()
	if current_clip == "Assemble":
		contact.enabled = false
	return true

func adjust_assembly() -> void:
	release_assembly()
	if current_clip != "Assemble" or dead or animator.current_animation_length <= 0.0:
		return
	var phase := animator.current_animation_position / animator.current_animation_length
	if phase <= 0.72:
		return
	var origin := global_position
	var ray := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.7, origin - Vector3.UP * 1.6, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < 0.75:
		return
	if assembly_skin.is_empty():
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		assembly_skin = Ground.skin_points(mesh, skeleton)
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(assembly_skin, skeleton, skeleton.global_transform, hit.position, hit.normal)
	var lift := clampf((0.003 - gap) / hit.normal.y, 0.0, 0.38) * smoothstep(0.72, 0.98, phase)
	var prior := model.position
	model.global_position += Vector3.UP * lift
	assembly_shift = model.position - prior

func release_assembly() -> void:
	model.position -= assembly_shift
	assembly_shift = Vector3.ZERO
