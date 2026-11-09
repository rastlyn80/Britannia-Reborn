extends "res://Network/GoatHarpyHordeLive.gd"

func clear_fall(actor: Node3D) -> bool:
	if not check(actor.current_clip == "Death", "Both identical Classic fall groups select the source collapse"):
		return false
	return super.clear_fall(actor)
