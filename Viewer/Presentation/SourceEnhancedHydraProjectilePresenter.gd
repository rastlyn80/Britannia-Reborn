# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedDevourerProjectilePresenter.gd"


func _bolt_origin(effect: Dictionary) -> Vector3:
	if int(effect.graphic) == 0x36d4:
		var avatar := scene.avatars.get(int(effect.source)) as Avatar
		if avatar != null and avatar.native_body == 265 and is_instance_valid(avatar.horse_visual) \
				and avatar.horse_visual.has_method("fire_breath_origin"):
			var origin: Variant = avatar.horse_visual.fire_breath_origin()
			if origin is Vector3:
				return origin
	return super._bolt_origin(effect)
