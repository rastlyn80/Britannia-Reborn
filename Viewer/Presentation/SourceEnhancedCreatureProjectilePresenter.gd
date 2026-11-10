# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureProjectilePresenter.gd"

const Tessen := preload("SourceTessenMesh.gd")


func _bolt(effect: Dictionary, tint: Color) -> void:
	if int(effect.graphic) == 0x27a3 and not effect.explodes and throw_tessen(effect):
		return
	super._bolt(effect, tint)


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
