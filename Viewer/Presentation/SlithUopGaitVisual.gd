extends "res://Presentation/SlithActionsVisual.gd"

var gait := preload("res://Presentation/UopMonsterGait.gd").new()
var walk_clearance := Vector3.ZERO

func _ready() -> void:
	super._ready()
	contact.modification_processed.connect(support_peaceful_walk)

func _physics_process(delta: float) -> void:
	release_walk_clearance()
	super._physics_process(delta)

func settle() -> void:
	release_walk_clearance()
	super.settle()

func release_walk_clearance() -> void:
	model.position -= walk_clearance
	walk_clearance = Vector3.ZERO

func support_peaceful_walk() -> void:
	if dead or current_clip != "SlithPeaceWalk" or contact.contacts.is_empty():
		return
	release_walk_clearance()
	var hit: Dictionary = contact.contacts.values()[0]
	var gap := Ground.minimum_plane_gap(skin, skeleton, skeleton.global_transform, hit.position, hit.normal)
	if gap < 0.002:
		var before: Vector3 = model.position
		model.global_position.y += (0.002 - gap) / float(hit.normal.y)
		walk_clearance = model.position - before

func begin_death_from(source: Node3D) -> float:
	return fall.begin_from_source(self, source, source.fall, source.walk_clearance)

func set_native_combat_flags(flags: int) -> void:
	gait.set_flags(flags)

func play_gait(moving: bool, speed: float) -> void:
	if not gait.play(self, moving, speed, "SlithPeaceWalk"):
		super.play_gait(moving, speed)
