extends "res://Presentation/CreatureVisual.gd"

func receive_action(request: Dictionary) -> bool:
	var accepted := super.receive_action(request)
	if accepted and current_clip == "Assemble":
		contact.enabled = false
	return accepted
