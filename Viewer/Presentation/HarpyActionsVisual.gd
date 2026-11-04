extends "res://Presentation/MongbatActionsVisual.gd"
## Retain Harpy's foot-release behavior during the original Wingbeat.

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if current_clip == "Wingbeat":
		contact.enabled = false
	return true
