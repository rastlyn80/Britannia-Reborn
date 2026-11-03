extends "res://Presentation/CreatureVisual.gd"

const LegSupport = preload("res://Presentation/MephitisGroundSupport.gd")


func _ready() -> void:
	super._ready()
	contact.free()
	contact = LegSupport.new()
	contact.align_skinned_soles = true
	contact.iterations = 5
	skeleton.add_child(contact)
	contact.configure(model.find_children("*", "MeshInstance3D", true, false)[0], false)
