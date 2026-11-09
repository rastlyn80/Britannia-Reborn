extends RefCounted
## These sequence variants use the same fitted clips as the direct Classic groups.

static func entry_for_packet(entry: Dictionary, request: Dictionary) -> Dictionary:
	if request.get("protocol") != "new" or int(request.get("variation", 0)) != 1:
		return entry
	var kind := int(request.type)
	var group := 0
	if kind == 0 and int(request.get("subaction", 0)) not in [1, 2, 9]:
		group = 5
	elif kind == 3:
		group = 3
	if group == 0:
		return entry
	return entry.merged({"new_action_categories": {str(kind): entry.classic_action_categories[str(group)]}}, true)
