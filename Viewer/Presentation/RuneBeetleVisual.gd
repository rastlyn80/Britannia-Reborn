extends "res://Presentation/OccurrenceCreatureVisual.gd"


func _ready() -> void:
	super._ready()
	# The front stance chains use the original arm and hand joint labels.
	contact.feet.clear()
	var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	contact.configure(mesh, true)
