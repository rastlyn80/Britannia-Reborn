# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedArmoredGargoyleProjectilePresenter.gd"

const HoundBreath := preload("res://Presentation/HellHoundBreathOrigin.gd")


func _bolt_origin(effect: Dictionary) -> Vector3:
	var origin: Variant = HoundBreath.resolve(scene, effect)
	return origin if origin is Vector3 else super._bolt_origin(effect)


func _expire(node: Node, seconds: float) -> void:
	var timer := node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	timer.tween_interval(seconds)
	timer.tween_callback(node.queue_free)


func _bloom(at: Vector3, tint: Color, effect: Dictionary, follow := 0) -> void:
	preload("res://Presentation/CreatureBloom.gd").present(self, at, tint, effect, follow)
