extends "res://Presentation/CreatureVisual.gd"


func _ready() -> void:
	super._ready()
	# The long toes need ground correction measured at the skinned sole.
	contact.align_skinned_soles = true
	contact.iterations = 8
