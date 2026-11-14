# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureEffectPresenter.gd"

const BowVisual := preload("res://Presentation/CentaurBowVisual.gd")
const BowRelease := preload("res://Presentation/CentaurBowRelease.gd")
# Low-Poly Arrow v2.0 by Teslov, CC BY 4.0. See Art/Objaverse/manifest.json.
const ARROW := preload("res://Art/Objaverse/arrow_lowpoly/arrow_lowpoly.glb")
const SHURIKEN := 0x27ac
const FUKIYA_DART := 0x2804
const FOOLS_GOLD := 0x0eef
var ninja_projectile_meshes := {}
var treasure_mesh: Mesh

func _bolt_origin(effect: Dictionary) -> Vector3:
	if int(effect.graphic) == 0x36d4:
		var avatar := scene.avatars.get(int(effect.source)) as Avatar
		if avatar != null and avatar.native_body in [90, 293] and is_instance_valid(avatar.horse_visual):
			var creature := avatar.horse_visual
			if creature.has_method("fire_breath_origin"):
				var origin: Variant = creature.fire_breath_origin()
				if origin is Vector3:
					return origin
	return super._bolt_origin(effect)

func _bolt(effect: Dictionary, tint: Color) -> void:
	var actor := scene.avatars.get(int(effect.source)) as Avatar
	if int(effect.graphic) == FOOLS_GOLD and actor != null and actor.native_body == 722 and effect.explodes:
		_launch_treasure(effect)
		return
	if int(effect.graphic) in [SHURIKEN, FUKIYA_DART] and not effect.explodes and launch_ninja_projectile(actor, effect):
		return
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

func _launch_treasure(effect: Dictionary) -> void:
	var from := _point(int(effect.source), effect.from) + Vector3.UP * .85
	var to := _point(int(effect.target), effect.to) + Vector3.UP * .7
	var projectile := MeshInstance3D.new()
	projectile.name = "NativeFoolsGold"
	projectile.mesh = _gold_pile_mesh()
	add_child(projectile)
	projectile.global_position = from
	var flight := create_tween()
	flight.tween_method(func(phase: float):
		projectile.global_position = from.lerp(to, phase) + Vector3.UP * (.55 * sin(PI * phase))
		projectile.rotation = Vector3(phase * TAU * 2., phase * TAU, 0.), 0., 1., .9)
	flight.tween_callback(projectile.queue_free)


func _gold_pile_mesh() -> Mesh:
	if treasure_mesh != null:
		return treasure_mesh
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("#d9a62e")
	metal.metallic = .85
	metal.roughness = .43
	var coin := CylinderMesh.new()
	coin.top_radius = .057
	coin.bottom_radius = .057
	coin.height = .014
	coin.radial_segments = 12
	coin.rings = 0
	var heap := SurfaceTool.new()
	heap.begin(Mesh.PRIMITIVE_TRIANGLES)
	heap.set_material(metal)
	for index in 9:
		var angle := index * 2.39996
		var distance := .067 if index < 6 else .034
		var offset := Vector3(cos(angle) * distance, .013 * (index / 3), sin(angle) * distance)
		heap.append_from(coin, 0, Transform3D(Basis(Vector3.FORWARD, .2 * sin(angle)), offset))
	treasure_mesh = heap.commit()
	return treasure_mesh


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


func launch_ninja_projectile(actor: Node3D, effect: Dictionary) -> bool:
	if actor == null or not is_instance_valid(actor.human_visual):
		return false
	var graphic := int(effect.graphic)
	var rig: Skeleton3D = actor.human_visual.skeleton
	var joint := rig.find_bone("hand_r" if graphic == SHURIKEN else "head")
	if joint < 0:
		return false
	var origin := rig.to_global(rig.get_bone_global_pose(joint).origin)
	if graphic == FUKIYA_DART:
		origin += -actor.global_basis.z.normalized() * .09 - Vector3.UP * .057
	var destination := _point(int(effect.target), effect.to)
	var delta := destination - origin
	if delta.length_squared() <= .0001:
		return false
	var direction := delta.normalized()
	var projectile := MeshInstance3D.new()
	projectile.name = "NativeShuriken" if graphic == SHURIKEN else "NativeFukiyaDart"
	projectile.mesh = ninja_projectile_mesh(graphic)
	add_child(projectile)
	projectile.global_position = origin
	projectile.look_at(destination, Vector3.RIGHT if absf(direction.y) > .99 else Vector3.UP)
	var attitude := projectile.global_basis
	var duration := clampf(delta.length() / (6.0 + float(effect.speed)), .15, 1.6)
	var flight := create_tween()
	flight.tween_method(func(phase: float):
		projectile.global_position = origin.lerp(destination, phase) + Vector3.UP * (.09 * sin(PI * phase))
		if graphic == SHURIKEN:
			projectile.global_basis = Basis(direction, phase * TAU * 3.0) * attitude,
		0.0, 1.0, duration)
	flight.tween_callback(projectile.queue_free)
	return true


func ninja_projectile_mesh(graphic: int) -> Mesh:
	if ninja_projectile_meshes.has(graphic):
		return ninja_projectile_meshes[graphic]
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("#929c9e")
	metal.metallic = .73
	metal.roughness = .38
	var mesh: Mesh
	if graphic == SHURIKEN:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		metal.cull_mode = BaseMaterial3D.CULL_DISABLED
		surface.set_material(metal)
		for point in 8:
			var angle := point * TAU / 8
			var tip := Vector3(sin(angle), cos(angle), 0) * (.085 if point % 2 == 0 else .028)
			var next_angle := angle + TAU / 8
			var next := Vector3(sin(next_angle), cos(next_angle), 0) * (.028 if point % 2 == 0 else .085)
			for vertex in [Vector3.ZERO, tip, next]:
				surface.add_vertex(vertex)
		surface.generate_normals()
		mesh = surface.commit()
	else:
		var dart := CylinderMesh.new()
		dart.top_radius = 0.0
		dart.bottom_radius = .012
		dart.height = .19
		dart.radial_segments = 8
		dart.rings = 0
		dart.material = metal
		var aligned := SurfaceTool.new()
		aligned.begin(Mesh.PRIMITIVE_TRIANGLES)
		aligned.set_material(metal)
		aligned.append_from(dart, 0, Transform3D(Basis(Vector3.RIGHT, -PI * .5), Vector3.ZERO))
		mesh = aligned.commit()
	ninja_projectile_meshes[graphic] = mesh
	return mesh
