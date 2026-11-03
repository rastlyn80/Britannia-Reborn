extends "res://Presentation/CreatureVisual.gd"


func _ready() -> void:
	super._ready()
	# The curved source paws need a skinned-sole target on sloped ground.
	contact.align_skinned_soles = true
	contact.iterations = 8
