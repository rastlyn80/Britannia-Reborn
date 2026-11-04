extends "res://Presentation/SourceArmedLizardmanVisual.gd"
## Reuse the armed body's body-and-weapon terrain solver for explicit collapses.

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if not dead:
		death_skin.clear()
		return true
	if death_skin.is_empty():
		death_model = model.transform
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if mesh.skin != null:
				death_skin.append(Ground.skin_points(mesh, skeleton))
	return true
