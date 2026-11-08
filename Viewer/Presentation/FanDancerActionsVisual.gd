extends "res://Presentation/FanDancerVisual.gd"

const Fall := preload("res://Presentation/SourceSpaceFallPlayback.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const GUARDS := ["BlockRight", "FanGuardLeft", "FanFlourish"]

var fall := Fall.new()
var skin: Dictionary
var lift := 0.0

func _ready() -> void:
	super._ready()
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	skin = Ground.skin_points(mesh, skeleton)
	contact.modification_processed.connect(settle_stance)
	animator.mixer_applied.connect(settle_fall)

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	release_lift()
	fall.accept_action(self)
	return true

func _physics_process(delta: float) -> void:
	release_lift()
	super._physics_process(delta)

func release_lift() -> void:
	model.global_position.y -= lift
	lift = 0.0

func settle_stance() -> void:
	release_lift()
	if dead or current_clip not in GUARDS or contact.contacts.is_empty():
		return
	var hit: Dictionary = contact.contacts.values()[0]
	var normal: Vector3 = hit.normal
	if normal.y < 0.5:
		return
	var gap := Ground.minimum_plane_gap(skin, skeleton, skeleton.global_transform, hit.position, normal)
	lift = maxf(0.0, (0.002 - gap) / normal.y)
	model.global_position.y += lift

func begin_death_from(source: Node3D) -> float:
	return fall.begin_from_source(self, source, source.fall)

func settle_fall() -> void:
	if dead and not fall.plane.is_empty():
		fall.settle(self)

func corpse_snapshot_floor() -> float:
	return INF if fall.plane.is_empty() else fall.snapshot_floor(self)
