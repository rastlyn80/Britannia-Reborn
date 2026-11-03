extends "res://Presentation/CreatureVisual.gd"


func _ready() -> void:
	super._ready()
	contact.feet.clear()
	contact.configure(model.find_children("*", "MeshInstance3D", true, false)[0], true)
	contact.align_skinned_soles = true
	contact.iterations = 8
