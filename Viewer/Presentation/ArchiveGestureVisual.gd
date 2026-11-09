extends "res://Presentation/CreatureVisual.gd"

var ground_gesture := preload("res://Presentation/ArchiveGestureGround.gd").new()

func _ready() -> void:
	super._ready()
	ground_gesture.bind(self)

func _physics_process(delta: float) -> void:
	ground_gesture.release(self)
	super._physics_process(delta)
