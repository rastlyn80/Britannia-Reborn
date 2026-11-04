extends "res://Network/CreatureLive.gd"
## Report the exact native reaction on shared-body constructor trials.

func reply(sex: int, command: String, prefix: String) -> String:
	var response := await super.reply(sex, command, prefix)
	if command == "hurt" and not response.is_empty():
		var serial := int(response.get_slice("|", 2))
		print("SHARED BODY HURT: ", sessions[sex].last_mobile_actions.get(serial),
			" / ", sessions[1 - sex].last_mobile_actions.get(serial))
	return response
