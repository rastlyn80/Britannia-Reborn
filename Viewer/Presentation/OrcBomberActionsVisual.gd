extends "res://Presentation/SourcePreservingCreatureVisual.gd"

const BOMB_GRAPHIC := 0x1C19
const BOMB_PARTICLES := 9502
const BOMB_IMPACT := 6014
const FOLLOW_THROUGH := "BombFollowThrough"

func begin_bomb_effect(effect: Dictionary) -> Variant:
	if dead or effect.get("kind") != "moving" or int(effect.get("graphic", 0)) != BOMB_GRAPHIC:
		return null
	if int(effect.get("speed", 0)) != 1 or int(effect.get("duration", -1)) != 0 or not effect.get("explodes", false):
		return null
	# ModernUO sends a hued effect to clients without particle effects enabled.
	if effect.has("tile") and (int(effect.tile) != BOMB_PARTICLES or int(effect.explode_effect) != BOMB_IMPACT):
		return null
	if not animator.has_animation(FOLLOW_THROUGH):
		return null
	var palm := skeleton.find_bone("cp_grasp_rhand")
	assert(palm >= 0)
	var origin := skeleton.to_global(skeleton.get_bone_global_pose(palm).origin)
	current_clip = FOLLOW_THROUGH
	action_remaining = animator.get_animation(FOLLOW_THROUGH).length
	animator.speed_scale = 1.0
	animator.play(FOLLOW_THROUGH, 0.04)
	animator.seek(0.0, false)
	set_meta("native_bomb_effect", effect.duplicate(true))
	return origin
