extends "res://Presentation/SourceSolenWarriorVisual.gd"

func _ready() -> void:
	super._ready()
	ground_curves = ground_curves.merged(Ground.load_curves(str(entry.action_ground_lookup), treatment))
