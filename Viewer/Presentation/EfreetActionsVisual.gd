extends "res://Presentation/TerathanActionsVisual.gd"

func receive_action(request: Dictionary) -> bool:
	var group := sequence_group(request)
	if group < 0:
		return super.receive_action(request)
	# Use the selected Classic slot without applying Classic wire timing to a
	# newer packet. Keep the original packet available to observers and probes.
	var selection := request.duplicate()
	selection.merge({"protocol": "classic", "action": group, "frames": 0}, true)
	var accepted := super.receive_action(selection)
	set_meta("native_action" if accepted else "unsupported_action", request.duplicate(true))
	return accepted

func sequence_group(request: Dictionary) -> int:
	if request.get("protocol") != "new":
		return -1
	var variation := int(request.get("variation", 0))
	if request.get("type") == 3:
		return 3 if variation == 1 else 2
	if request.get("type") == 0:
		var subaction := int(request.get("subaction", 0))
		return 5 if variation == 1 and subaction not in [1, 2, 9] else 4
	return -1
