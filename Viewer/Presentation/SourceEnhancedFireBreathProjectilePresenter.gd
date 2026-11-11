# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedHydraProjectilePresenter.gd"


func _bolt_origin(effect: Dictionary) -> Vector3:
	if int(effect.graphic) == 0x36d4:
		var avatar := scene.avatars.get(int(effect.source)) as Avatar
		if avatar != null and avatar.native_body != 265 and is_instance_valid(avatar.horse_visual):
			var actor: Node3D = avatar.horse_visual
			if actor.has_method("fire_breath_origin"):
				var origin: Variant = actor.fire_breath_origin()
				if origin is Vector3:
					return origin
	return super._bolt_origin(effect)
