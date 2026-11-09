extends "res://Network/GoatHarpyHordeLive.gd"

func clear_fall(actor: Node3D) -> bool:
	if actor.native_body != 778:
		return super.clear_fall(actor)
	if not check(actor.dead and actor.current_clip == "Death", "Gazer Larva uses the original hover fall"):
		return false
	actor.dead = false
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	return true
