extends "res://Presentation/CreatureVisual.gd"


func _ready() -> void:
	super._ready()
	# Correct against deformed sole vertices on slopes.
	contact.align_skinned_soles = true
	contact.iterations = 8
