# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureProjectilePresenter.gd"

const HoundBreath := preload("res://Presentation/HellHoundBreathOrigin.gd")



var occurrence := preload("res://Presentation/CreatureOccurrenceEffects.gd").new()


func configure(world_scene: Node3D) -> void:
	super.configure(world_scene)
	occurrence.configure(self, world_scene)


func present(effect: Dictionary) -> void:
	if not occurrence.present(effect):
		super.present(effect)


func _bolt_origin(effect: Dictionary) -> Vector3:
	var origin: Variant = occurrence.bolt_origin(effect)
	if not origin is Vector3:
		origin = HoundBreath.resolve(scene, effect)
	return origin if origin is Vector3 else super._bolt_origin(effect)


func _expire(node: Node, seconds: float) -> void:
	var timer := node.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	timer.tween_interval(seconds)
	timer.tween_callback(node.queue_free)


func _bloom(at: Vector3, tint: Color, effect: Dictionary, follow := 0) -> void:
	preload("res://Presentation/CreatureBloom.gd").present(self, at, tint, effect, follow)


func _bolt(effect: Dictionary, tint: Color) -> void:
	var leech_target: Variant = occurrence.leech_target(effect)
	if not leech_target is Vector3:
		super._bolt(effect, tint)
		return
	var from := _bolt_origin(effect)
	var to: Vector3 = leech_target
	var core := MeshInstance3D.new()
	core.mesh = SphereMesh.new()
	core.mesh.radius = 0.1
	core.mesh.height = 0.2
	var material := _glow(tint,6.0)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	core.material_override = material
	core.position = from
	add_child(core)
	var trail := sparks(tint,40,0.45,0.06,0.4)
	trail.local_coords = false
	core.add_child(trail)
	var glow := OmniLight3D.new()
	glow.light_color = tint
	glow.light_energy = 1.6
	glow.omni_range = 3.0
	core.add_child(glow)
	var seconds := clampf(from.distance_to(to)/(6.0+float(effect.speed)),0.15,1.6)
	var flight := create_tween()
	flight.tween_property(core,"position",to,seconds)
	flight.tween_callback(func():
		if effect.explodes: _burst(to,tint)
		core.queue_free())
