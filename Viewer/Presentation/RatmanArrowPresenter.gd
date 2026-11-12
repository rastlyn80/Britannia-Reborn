# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureProjectilePresenter.gd"

const Archer := preload("res://Presentation/SourceRatmanArcherVisual.gd")


func route_alongside(world: Node3D, fallback: Node3D) -> void:
	scene = world
	var effects: Signal = scene.game.module("effects").spawned
	effects.disconnect(fallback.present)
	effects.connect(func(effect: Dictionary):
		if not present_ratman_arrow(effect):
			fallback.present(effect))


func present_ratman_arrow(effect: Dictionary) -> bool:
	if scene.game.phase != "world" or effect.kind != "moving" or int(effect.graphic) != 0x0f42 or effect.explodes:
		return false
	var actor := scene.avatars.get(int(effect.source)) as Avatar
	if actor == null or actor.native_body != 142:
		return false
	var archer := actor.horse_visual as Archer
	if archer == null:
		return false
	var to := _point(int(effect.target), effect.to)
	var release_time := archer.begin_bow_release(to)
	if release_time < 0.0:
		return false
	var fallback := archer.bow_arrow_origin()
	var speed := float(effect.speed)
	var archer_ref: WeakRef = weakref(archer)
	var flight := create_tween()
	flight.tween_interval(release_time)
	flight.tween_callback(func():
		var current := archer_ref.get_ref() as Archer
		var from := current.bow_arrow_origin() if current != null and current.bow_release_available() else fallback
		_fly_arrow(from, to, speed)
		get_child(-1).name = &"NativeRatmanArrow")
	return true
