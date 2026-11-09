extends "res://Presentation/EffectPresenter.gd"

func _bolt_origin(effect: Dictionary) -> Vector3:
	var source := int(effect.source)
	if int(effect.graphic) == 0x1c19 and scene.avatars.has(source):
		var avatar: Node3D = scene.avatars[source]
		if avatar is Avatar and is_instance_valid(avatar.horse_visual) and avatar.horse_visual.has_method("begin_bomb_effect"):
			var origin: Variant = avatar.horse_visual.begin_bomb_effect(effect)
			if origin is Vector3:
				return origin
	return super._bolt_origin(effect)
