extends "res://Presentation/CreatureVisual.gd"


func _ready() -> void:
	super._ready()
	# Use skinned sole vertices to keep the source feet above sloped ground.
	contact.align_skinned_soles = true
	contact.iterations = 8
