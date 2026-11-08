extends "res://Presentation/TerathanActionsVisual.gd"
## Both insect rigs use the same full-skin support for the selected actions.

func _ready() -> void:
	super._ready()
	contact.align_skinned_soles = true
	contact.iterations = 8
