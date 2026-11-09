extends "res://Presentation/TerathanActionsVisual.gd"

func _ready() -> void:
	super._ready()
	contact.align_skinned_soles = true
	contact.iterations = 8

func receive_action(request: Dictionary) -> bool:
	var alternate := alternate_clip(request)
	if alternate.is_empty():
		return super.receive_action(request)
	# Use the normal newer-packet player with a per-call category. The shared
	# registry entry and the original packet remain available to other actors.
	var original := entry
	entry = entry.merged({"new_action_categories": {str(request.type): alternate}}, true)
	var accepted := super.receive_action(request)
	entry = original
	return accepted

func alternate_clip(request: Dictionary) -> String:
	if request.get("protocol") != "new" or int(request.get("variation", 0)) != 1:
		return ""
	match int(request.type):
		0:
			if int(request.get("subaction", 0)) not in [1, 2, 9]:
				return "Attack2"
		3:
			return "Death2"
		5:
			return "SlithThreatRise"
	return ""
