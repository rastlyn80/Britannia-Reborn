extends "res://Presentation/CreatureVisual.gd"

const Fall := preload("res://Presentation/SourceSpaceFallPlayback.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const NEW_LIVING := ["DoubleWhip", "CurlAndRise"]
var fall := Fall.new()
var live_shift := Vector3.ZERO

func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(settle)

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if current_clip in Fall.FALLS:
		fall.accept_action(self)
	return true

func settle() -> void:
	if live_shift != Vector3.ZERO:
		model.position -= live_shift
		live_shift = Vector3.ZERO
	if not fall.plane.is_empty() and dead:
		fall.settle(self)
		return
	if current_clip not in NEW_LIVING:
		return
	var support := fall.floor_under(self)
	if fall.skin.is_empty():
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		fall.skin = Ground.skin_points(mesh, skeleton)
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(fall.skin, skeleton, skeleton.global_transform, support.position, support.normal)
	var before := model.position
	model.global_position += Vector3.UP * (0.003 - gap) / float(support.normal.y)
	live_shift = model.position - before

func begin_death_from(source: Node3D) -> float:
	return fall.begin_from_source(self, source, source.fall, source.live_shift)

func corpse_snapshot_floor() -> float:
	return INF if fall.plane.is_empty() else fall.snapshot_floor(self)
