# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureProjectilePresenter.gd"

const Tessen := preload("SourceTessenMesh.gd")


func _bolt_origin(effect: Dictionary) -> Vector3:
	if int(effect.graphic) == 0x36d4:
		var avatar := scene.avatars.get(int(effect.source)) as Avatar
		if avatar != null and avatar.native_body == 734 and is_instance_valid(avatar.horse_visual) \
				and avatar.horse_visual.has_method("fire_breath_origin"):
			var origin: Variant = avatar.horse_visual.fire_breath_origin()
			if origin is Vector3:
				return origin
	return super._bolt_origin(effect)


func _bolt(effect: Dictionary, tint: Color) -> void:
	if int(effect.graphic) == 0x27a3 and not effect.explodes and throw_tessen(effect):
		return
	if int(effect.graphic) == 0x0f42 and not effect.explodes and release_juka_arrow(effect):
		return
	super._bolt(effect, tint)


func release_juka_arrow(effect: Dictionary) -> bool:
	var avatar := scene.avatars.get(int(effect.source)) as Avatar
	if avatar == null or avatar.native_body != 766 or not is_instance_valid(avatar.horse_visual):
		return false
	var archer: Node3D = avatar.horse_visual
	if not archer.has_method("begin_bow_release"):
		return false
	var delay: float = archer.begin_bow_release()
	if delay < 0.0:
		return false
	var fallback: Vector3 = archer.bow_arrow_origin()
	var target := _point(int(effect.target), effect.to)
	var speed := float(effect.speed)
	var reference: WeakRef = weakref(archer)
	var release := func():
		var current: Node3D = reference.get_ref()
		var origin: Vector3 = current.bow_arrow_origin() if current != null and current.bow_release_available() else fallback
		_fly_arrow(origin, target, speed)
	if delay > 0.0:
		var flight := create_tween()
		flight.tween_interval(delay)
		flight.tween_callback(release)
	else:
		release.call()
	return true


func throw_tessen(effect: Dictionary) -> bool:
	var dancer := fan_at_origin(effect)
	if dancer == null:
		return false
	var captured := Tessen.capture(dancer, int(effect.hue))
	if captured.is_empty():
		return false
	var destination := _point(int(effect.target), effect.to)
	var origin: Vector3 = captured.centre
	var path := destination - origin
	if path.length_squared() < .001:
		return false
	var fan := MeshInstance3D.new()
	fan.name = "NativeFanThrow"
	fan.mesh = captured.mesh
	add_child(fan)
	fan.global_position = origin
	var spin := Vector3.UP.cross(path.normalized()).normalized()
	if spin.is_zero_approx():
		spin = Vector3.RIGHT
	var travel := clampf(path.length() / (6.0 + float(effect.speed)), .15, 1.6)
	var flight := create_tween()
	flight.tween_method(func(phase: float):
		fan.global_position = origin.lerp(destination, phase) + Vector3.UP * (.16 * sin(PI * phase))
		fan.global_basis = Basis(spin, phase * TAU * 1.15), 0.0, 1.0, travel)
	flight.tween_callback(fan.queue_free)
	return true


func fan_at_origin(effect: Dictionary) -> Node3D:
	var origin: Vector3i = effect.from
	var source := int(effect.source)
	var matching: Node3D
	for serial: int in scene.avatars:
		if source != 0 and serial != source:
			continue
		var mobile: Dictionary = scene.game.entities.get(serial, {})
		if int(mobile.get("body", 0)) != 247 or Vector3i(mobile.x, mobile.y, mobile.z) != origin:
			continue
		var avatar: Node3D = scene.avatars[serial]
		var dancer: Node3D = avatar.horse_visual
		if not avatar.is_visible_in_tree() or not is_instance_valid(dancer) or dancer.dead:
			continue
		if matching != null:
			return null
		matching = dancer
	if matching == null or matching.treatment != "modern":
		return null
	return matching if "FanDancerSteppingSweep" in matching.entry.get("archive_grounded_gestures", []) else null
