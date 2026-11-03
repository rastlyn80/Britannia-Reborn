extends "res://Presentation/OccurrenceCreatureVisual.gd"

const Support = preload("res://Presentation/FanDancerSupport.gd")


func _ready() -> void:
	super._ready()
	contact.free()
	contact = Support.new()
	skeleton.add_child(contact)
	contact.align_skinned_soles = true
	contact.iterations = 8
	contact.configure(model.find_children("*", "MeshInstance3D", true, false)[0], false)
