extends "res://Presentation/SourcePreservingCreatureVisual.gd"

const Fall := preload("res://Presentation/SourceSpaceFallPlayback.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Variants := preload("res://Presentation/CreatureModeZeroVariants.gd")
var fall := Fall.new()
var wing_skin: Dictionary
var wing_lift := Vector3.ZERO

func _ready() -> void:
	super._ready()
	if animator.has_animation("ChangelingWingRoll"):
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		wing_skin = Ground.skin_points(mesh, skeleton)
	animator.mixer_applied.connect(settle_action)

func receive_action(request: Dictionary) -> bool:
	var original := entry
	entry = Variants.entry_for_packet(entry, request)
	var accepted := super.receive_action(request)
	entry = original
	if not accepted:
		return false
	fall.accept_action(self)
	if current_clip == "ChangelingWingRoll":
		contact.enabled = false
	return true

func _physics_process(delta: float) -> void:
	if not dead and current_clip != "ChangelingWingRoll":
		super._physics_process(delta)

func support_control_plane() -> void:
	if not dead and current_clip != "ChangelingWingRoll":
		super.support_control_plane()

func settle_action() -> void:
	model.position -= wing_lift
	wing_lift = Vector3.ZERO
	if dead and not fall.plane.is_empty():
		fall.settle(self)
	elif current_clip == "ChangelingWingRoll":
		var plane := fall.floor_under(self)
		var gap := Ground.minimum_plane_gap(wing_skin, skeleton, skeleton.global_transform, plane.position, plane.normal)
		if gap < 0.002:
			var anchor := model.position
			model.global_position.y += (0.002 - gap) / float(plane.normal.y)
			wing_lift = model.position - anchor
	update_landmarks()

func begin_death_from(source: Node3D) -> float:
	if source.dead:
		return fall.begin_from_source(self, source, source.fall)
	return super.begin_death_from(source)

func corpse_snapshot_floor() -> float:
	return INF if fall.plane.is_empty() else fall.snapshot_floor(self)
