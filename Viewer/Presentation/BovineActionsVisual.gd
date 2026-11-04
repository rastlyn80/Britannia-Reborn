extends "res://Presentation/BovineVisual.gd"
## Distinct cattle actions on the retained source rig, including the two collapses.
const Timing := preload("res://Presentation/HumanActions.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const ADDITIONAL_CLIPS := {6: "Attack2", 10: "Fidget2", 12: "Death2"}
var collapse_plane: Dictionary = {}
var collapse_skin: Dictionary = {}
var collapse_shift := Vector3.ZERO

func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(settle_collapse)

func model_resource_path(_folder: String, asset_kind: String) -> String:
	return asset_path(asset_kind, treatment)

static func asset_path(asset_kind: String, treatment: String) -> String:
	return "res://local-art/animals/%s-%s-actions.scn" % [asset_kind, treatment]

static func available(asset_kind: String) -> bool:
	for variant: String in ["original", "rounded", "modern"]:
		if not ResourceLoader.exists(asset_path(asset_kind, variant)):
			return false
	return true

func receive_action(request: Dictionary) -> bool:
	var group := int(request.get("action", -1))
	if str(request.get("protocol", "")) != "classic" or not ADDITIONAL_CLIPS.has(group):
		if not super.receive_action(request):
			return false
		if dead:
			set_collapse_plane(support_plane())
		return true
	var clip: String = ADDITIONAL_CLIPS[group]
	if dead and clip != "Death2":
		return false
	recovering_tip = false
	current_clip = clip
	dead = clip == "Death2"
	contact.enabled = not dead
	if dead:
		set_collapse_plane(support_plane())
	var duration := animator.get_animation(clip).length
	action_remaining = Timing.duration(request, duration)
	animator.speed_scale = 1.0
	animator.play(clip, 0.12, duration / action_remaining)
	animator.seek(0.0, false)
	set_meta("native_action", request.duplicate(true))
	return true

func support_plane() -> Dictionary:
	if not collapse_plane.is_empty():
		return collapse_plane
	if not contact.contacts.is_empty():
		return contact.contacts.values()[0]
	var origin := global_position
	var ray := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.6, origin - Vector3.UP * 1.6, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and hit.normal.y > 0.75:
		return hit
	return {"position": origin, "normal": Vector3.UP}

func set_collapse_plane(hit: Dictionary) -> void:
	collapse_plane = hit
	if collapse_skin.is_empty():
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		collapse_skin = Ground.skin_points(mesh, skeleton)

func begin_death_from(source: Node3D) -> float:
	recovering_tip = false
	dead = true
	contact.enabled = false
	set_collapse_plane(source.support_plane())
	model.position -= source.collapse_shift
	current_clip = str(source.current_clip) if source.dead else "Death"
	var position: float = source.animator.current_animation_position if source.dead else 0.0
	animator.speed_scale = 1.0
	animator.play(current_clip, 0.0)
	animator.advance(0.0)
	animator.seek(position, true)
	action_remaining = animator.current_animation_length - position
	return action_remaining

func settle_collapse() -> void:
	if not dead or collapse_plane.is_empty():
		return
	model.position -= collapse_shift
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(collapse_skin, skeleton, skeleton.global_transform,
		collapse_plane.position, collapse_plane.normal)
	var shift := 0.002 - gap
	if shift < 0.0:
		var phase := animator.current_animation_position / animator.current_animation_length
		shift *= smoothstep(0.75, 1.0, phase)
	var prior := model.position
	model.global_position += collapse_plane.normal * shift
	collapse_shift = model.position - prior

func corpse_snapshot_floor() -> float:
	skeleton.force_update_all_bone_transforms()
	var local_rig := global_transform.affine_inverse() * skeleton.global_transform
	return Ground.minimum_plane_gap(collapse_skin, skeleton, local_rig, Vector3.ZERO, Vector3.UP)
