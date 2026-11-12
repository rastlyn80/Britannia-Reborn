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
	var aim_ref: WeakRef = weakref(archer.aim)
	var shot := {"launched": false}
	var launch := func(from: Vector3):
		if shot.launched:
			return
		shot.launched = true
		_fly_arrow(from, to, speed)
		get_child(-1).name = &"NativeRatmanArrow"
	archer.aim.released.connect(launch, CONNECT_ONE_SHOT)
	var flight := create_tween()
	flight.tween_interval(release_time + 1.0 / 60.0)
	flight.tween_callback(func():
		if shot.launched:
			return
		var aim := aim_ref.get_ref() as Archer.BowAim
		if aim != null and aim.released.is_connected(launch):
			aim.released.disconnect(launch)
		launch.call(fallback))
	return true
