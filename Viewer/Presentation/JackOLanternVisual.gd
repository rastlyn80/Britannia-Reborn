# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureVisual.gd"

const Hue := preload("res://Presentation/HumanHue.gd")
const SPIRIT_BOX := AABB(Vector3(-.90, -.90, -1.05), Vector3(1.80, 1.88, 1.89))

var gourd: Node3D
var spirit: Node3D
var sole_points := PackedVector3Array()
var gourd_box: AABB
var floor_plane := {}
var flame_materials: Array[ShaderMaterial] = []
var flame_time := 0.0
var painted_hue := -1

func _ready() -> void:
	super._ready()
	contact.active = false
	gourd = model.get_node("Gourd")
	spirit = model.get_node("Spirit")
	var inverse := gourd.global_transform.affine_inverse()
	var seen := {}
	for mesh: MeshInstance3D in gourd.get_node("LicensedPumpkin").find_children("*", "MeshInstance3D", true, false):
		var transform := inverse * mesh.global_transform
		for surface in mesh.mesh.get_surface_count():
			for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var local := transform * point
				if not seen.has(local):
					seen[local] = true
					gourd_box = AABB(local, Vector3.ZERO) if sole_points.is_empty() else gourd_box.expand(local)
					sole_points.append(local)
	assert(not sole_points.is_empty())
	animator.mixer_applied.connect(place_visual)
	place_visual()

func set_hue(value: int) -> void:
	hue = value
	if model == null or painted_hue == value:
		return
	painted_hue = value
	flame_materials.clear()
	var palette := Hue.palette(value)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.has_meta("ephemeral_flame"):
			var flame := mesh.get_meta("original_flame", mesh.material_override) as ShaderMaterial
			mesh.set_meta("original_flame", flame)
			var visual := flame.duplicate() as ShaderMaterial
			visual.set_shader_parameter("hue_palette", palette)
			visual.set_shader_parameter("use_hue", palette != null and (value & 0x8000) == 0)
			visual.set_shader_parameter("phase", flame_time)
			mesh.material_override = visual
			flame_materials.append(visual)
			continue
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.material_override as StandardMaterial3D
			if original != null:
				mesh.set_meta("original_solid", original)
				mesh.material_override = null
			var base := mesh.get_meta("original_solid", null) as StandardMaterial3D if mesh.has_meta("original_solid") else mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if base != null:
				mesh.set_surface_override_material(surface, Hue.material(base, value) if palette != null else base)

func _process(delta: float) -> void:
	super._process(delta)
	if spirit != null and spirit.visible:
		flame_time = fposmod(flame_time + 1.9 * delta, 4096.)
		for flame: ShaderMaterial in flame_materials:
			flame.set_shader_parameter("phase", flame_time)

func _physics_process(_delta: float) -> void:
	if dead:
		return
	floor_plane = read_floor(self)
	place_visual()

func read_floor(actor: Node3D) -> Dictionary:
	var p := actor.global_position
	var ray := PhysicsRayQueryParameters3D.create(p + Vector3.UP * .80, p - Vector3.UP * .70, 1)
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit if not hit.is_empty() and hit.normal.y > .72 else {"position": p, "normal": Vector3.UP}

func lowest_gourd(transform: Transform3D, point: Vector3, normal: Vector3) -> float:
	var minimum := INF
	for vertex: Vector3 in sole_points:
		minimum = minf(minimum, normal.dot(transform * vertex - point))
	return minimum

func place_visual() -> void:
	if gourd == null:
		return
	if not floor_plane.is_empty():
		var normal: Vector3 = floor_plane.normal
		var gap := lowest_gourd(gourd.global_transform, floor_plane.position, normal)
		var rise := clampf((.002 - gap) / normal.y, -.68, .68)
		model.global_position += Vector3.UP * rise
	var inverse := global_transform.affine_inverse()
	var bounds := (inverse * gourd.global_transform) * gourd_box
	if spirit.visible:
		bounds = bounds.merge((inverse * spirit.global_transform) * SPIRIT_BOX)
	set_meta("pick_bounds", bounds)
	set_meta("nameplate_height", bounds.end.y + .16)

func receive_action(request: Dictionary) -> bool:
	var accepted := super.receive_action(request)
	if accepted and dead:
		floor_plane = read_floor(self)
	return accepted

func begin_death_from(source: Node3D) -> float:
	floor_plane = source.floor_plane if not source.floor_plane.is_empty() else read_floor(source)
	var start: float = source.animator.current_animation_position if source.dead else 0.0
	var speed: float = absf(source.animator.get_playing_speed()) if source.dead else 1.0
	if is_zero_approx(speed):
		speed = 1.0
	animator.play("Death", 0.0, speed)
	animator.advance(0.0)
	animator.seek(start, true)
	place_visual()
	action_remaining = maxf(0., animator.current_animation_length - start) / speed
	return action_remaining

func corpse_snapshot_floor() -> float:
	return lowest_gourd(global_transform.affine_inverse() * gourd.global_transform, Vector3.ZERO, Vector3.UP)
