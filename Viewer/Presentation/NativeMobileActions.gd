# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Creature := preload("res://Presentation/CreatureVisual.gd")
const WireActions := preload("res://Presentation/CreatureWireActions.gd")

static func dispatch(avatar: Node3D, request: Dictionary) -> bool:
	var visual: Node3D = avatar.horse_visual
	# The native AI can send an ear fidget after the tunnel notice. Keep the
	# established tunnel pose while still allowing hit and death actions.
	if visual is Creature and visual.native_body == 205 and int(request.get("body", 0)) == 205 \
		and request.get("protocol") == "classic" and int(request.get("action", -1)) in [9, 10] \
		and visual.skeleton.has_node("NativeTunnelPose"):
		return true
	if not visual is Creature or int(request.get("body", 0)) != visual.native_body or not is_colossal_blow(request):
		return WireActions.dispatch(avatar, request)

	# The pinned server's stun reuses group 21. Play the body's live hit
	# reaction so a surviving mobile can resume locomotion after it recovers.
	var reaction := request.duplicate()
	reaction["action"] = 7 if visual.action_profile in ["animal", "sea"] else 10
	if not avatar.receive_native_action(reaction):
		return false
	visual.set_meta("native_action", request.duplicate(true))
	return true

static func is_colossal_blow(request: Dictionary) -> bool:
	return request.get("protocol") == "classic" and int(request.get("action", -1)) == 21 \
		and int(request.get("frames", -1)) == 6 and int(request.get("repeat_count", -1)) == 1 \
		and request.get("reverse") == false and request.get("repeat") == false and int(request.get("delay", -1)) == 0
