# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedCreatureProjectilePresenter.gd"

const Devourer := preload("res://Presentation/SourceEnhancedDevourerVisual.gd")
const MagicArrow := 0x36e4


func _bolt(effect: Dictionary, tint: Color) -> void:
	if int(effect.graphic) == MagicArrow and not effect.explodes and cue_magic_arrow(effect, tint):
		return
	super._bolt(effect, tint)


func cue_magic_arrow(effect: Dictionary, tint: Color) -> bool:
	var avatar := scene.avatars.get(int(effect.source)) as Avatar
	if avatar == null or not avatar.horse_visual is Devourer:
		return false
	var caster := avatar.horse_visual as Devourer
	var delay := caster.begin_magic_arrow()
	if delay < 0.0:
		return false
	var reference: WeakRef = weakref(caster)
	var origin := caster.magic_arrow_origin()
	var release := func():
		var current := reference.get_ref() as Devourer
		var displayed := current.magic_arrow_origin() if current != null and current.current_clip == Devourer.Cast and not current.dead else origin
		render_magic_arrow(effect, tint, displayed)
	if delay > 0.0:
		var flight := create_tween()
		flight.tween_interval(delay)
		flight.tween_callback(release)
	else:
		release.call()
	return true


func render_magic_arrow(effect: Dictionary, tint: Color, origin: Vector3) -> void:
	super._bolt(effect.merged({"devourer_origin": origin}), tint)


func _bolt_origin(effect: Dictionary) -> Vector3:
	if effect.get("devourer_origin") is Vector3:
		return effect.devourer_origin
	return super._bolt_origin(effect)
