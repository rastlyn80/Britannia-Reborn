extends "res://Presentation/CreatureVisual.gd"
## Opt-in for measured source bipeds. Other existing families keep their
## configured support until their actual gait/sole measurements justify it.
func _ready() -> void:
	super._ready()
	contact.free();contact=preload("res://Presentation/SourceBipedSupport.gd").new();skeleton.add_child(contact)
	contact.include_toe_descendants=true
	contact.configure(model.find_children("*","MeshInstance3D",true,false)[0],false)
