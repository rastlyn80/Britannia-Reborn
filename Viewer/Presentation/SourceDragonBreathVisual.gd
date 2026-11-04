extends "res://Presentation/CreatureVisual.gd"

const BREATH := "DragonBreath"

func _ready() -> void:
	super._ready()
	default_model_scale *= float(entry.get("dragon_asset_scale", 1.0))

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if current_clip == BREATH:
		# ModernUO sends five frames, then emits its projectile 1.3 seconds later.
		var length := animator.get_animation(BREATH).length
		if action_remaining < length:
			animator.speed_scale = action_remaining / length
			action_remaining = length
	return true

func fire_breath_origin() -> Variant:
	if dead or current_clip != BREATH or action_remaining <= 0.0:
		return null
	var muzzle := skeleton.find_bone("box15")
	return skeleton.to_global(skeleton.get_bone_global_pose(muzzle).origin) if muzzle >= 0 else null
