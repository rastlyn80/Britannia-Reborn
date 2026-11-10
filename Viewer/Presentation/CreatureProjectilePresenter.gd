# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureEffectPresenter.gd"

const BowVisual := preload("res://Presentation/CentaurBowVisual.gd")
const BowRelease := preload("res://Presentation/CentaurBowRelease.gd")
# Low-Poly Arrow v2.0 by Teslov, CC BY 4.0. See Art/Objaverse/manifest.json.
const ARROW := preload("res://Art/Objaverse/arrow_lowpoly/arrow_lowpoly.glb")

func _bolt(effect: Dictionary, tint: Color) -> void:
	var actor := scene.avatars.get(int(effect.source)) as Avatar
	if int(effect.graphic) != 0x0f42 or effect.explodes or actor == null or not actor.horse_visual is BowVisual:
		super._bolt(effect, tint)
		return
	var archer := actor.horse_visual as BowVisual
	if archer.native_body != 101 or archer.dead or archer.bow_id == 0 or not is_instance_valid(archer.bow):
		super._bolt(effect, tint)
		return
	var release := archer.skeleton.get_node_or_null("NativeBowRelease") as BowRelease
	if release == null:
		release = BowRelease.new()
		release.name = "NativeBowRelease"
		release.bind(archer)
	var to := _point(int(effect.target), effect.to)
	var fallback := release.arrow_rest()
	var release_ref: WeakRef = weakref(release)
	release.start(to)
	var flight := create_tween()
	flight.tween_interval(BowRelease.RELEASE_TIME)
	flight.tween_callback(func():
		var current := release_ref.get_ref() as BowRelease
		var from := current.arrow_rest() if current != null and current.available() else fallback
		_fly_arrow(from, to, float(effect.speed)))

func _fly_arrow(from: Vector3, to: Vector3, speed: float) -> void:
	var arrow := Node3D.new()
	arrow.name = "NativeCentaurArrow"
	var mesh := ARROW.instantiate() as Node3D
	mesh.position.y = -.0189
	arrow.add_child(mesh)
	add_child(arrow)
	arrow.global_position = from
	if from.distance_squared_to(to) > .000001:
		var axis := (to - from).normalized()
		arrow.look_at(to, Vector3.RIGHT if absf(axis.dot(Vector3.UP)) > .99 else Vector3.UP)
	var travel := clampf(from.distance_to(to) / (6.0 + speed), .15, 1.6)
	var flight := create_tween()
	flight.tween_property(arrow, "global_position", to, travel)
	flight.tween_callback(arrow.queue_free)
