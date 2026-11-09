extends RefCounted
## Native war-mode state selects the matching original UOP idle and walking groups.

var known := false
var combat := false

func set_flags(flags: int) -> void:
	known = true
	combat = (flags & 0x40) != 0

func play(owner: Node3D, moving: bool, speed: float, peaceful_walk: String) -> bool:
	var locomotion: Dictionary = owner.entry.get("locomotion", {})
	if not known or combat or moving and speed > float(locomotion.get("run_threshold_mps", 3.6)):
		return false
	if owner.current_clip == "LieDown" and moving:
		owner.action_remaining = 0.0
	if owner.dead or owner.action_remaining > 0.0 or owner.current_clip == "LieDown" and not moving:
		return true
	var clip := peaceful_walk if moving else "ReadyStance"
	owner.contact.enabled = true
	if owner.current_clip != clip:
		owner.current_clip = clip
		owner.play(clip, 0.18)
	var reference := maxf(0.01, float(locomotion.get("walk_reference_mps", 1.8)))
	owner.animator.speed_scale = clampf(speed / reference, float(locomotion.get("rate_min", 0.65)),
		float(locomotion.get("rate_max", 1.65))) if moving else 1.0
	return true
