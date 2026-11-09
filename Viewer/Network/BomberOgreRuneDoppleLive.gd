extends "res://Network/GoatHarpyHordeLive.gd"

func clear_fall(actor: Node3D) -> bool:
	if actor.native_body == 777:
		return super.clear_fall(actor)
	if not check(actor.dead, "Both clients enter the retained fall"):
		return false
	if actor.native_body == 83:
		actor.model.position -= actor.collapse_shift
		actor.collapse_shift = Vector3.ZERO
		actor.collapse_plane = {}
	actor.dead = false
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	return true
