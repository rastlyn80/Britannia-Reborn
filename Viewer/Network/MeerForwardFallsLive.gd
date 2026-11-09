extends "res://Network/SwampWidowJukaActionsLive.gd"

func clear_fall(actor: Node3D) -> bool:
	if not check(actor.dead and not actor.fall.skin.is_empty(), "Meer fall arms its skinned terrain support"):
		return false
	actor.model.position -= actor.fall.shift
	actor.fall.shift = Vector3.ZERO
	actor.fall.plane = {}
	return super.clear_fall(actor)
