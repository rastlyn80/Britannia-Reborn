# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SandVortexVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()
var ribbons: Node3D
var shells: Array[MeshInstance3D] = []
var shell_points: Array[PackedVector3Array] = []
var collapse_scale := Vector3.ONE
var collapse_start := 0.0
var collapse_blend := 0.0


func _ready() -> void:
	super._ready()
	terrain.actor = self
	terrain.extent = Vector2.ONE
	ribbons = model.get_node("Ribbons")
	for shell: MeshInstance3D in ribbons.get_children():
		shells.append(shell)
		shell_points.append(shell.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	settle_pose()


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	sample_floor()
	super._physics_process(delta)


func sample_floor() -> void:
	var floor := terrain.floor_under(self)
	terrain.plane = floor if floor.has("collider") else {}
	terrain.split = not terrain.plane.is_empty() and terrain.spans_treads(floor)


func update_energy_pose() -> void:
	super.update_energy_pose()
	if ribbons != null:
		settle_pose()


func settle_pose() -> void:
	terrain.release_live()
	if dead and collapse_blend > 0.0:
		var blend := clampf((animator.current_animation_position - collapse_start) / collapse_blend, 0.0, 1.0)
		ribbons.scale = collapse_scale.lerp(ribbons.scale, blend)
		if blend >= 1.0:
			collapse_blend = 0.0
	if terrain.plane.is_empty():
		return
	var minimum := INF
	var normal: Vector3 = terrain.plane.normal
	var floor: Vector3 = terrain.plane.position
	for index in shells.size():
		var space := shells[index].global_transform
		if terrain.split:
			minimum = minf(minimum, terrain.piece_step_gap(shell_points[index], space, terrain.plane))
		else:
			var local_normal := space.basis.transposed() * normal
			var offset := normal.dot(space.origin - floor)
			for point: Vector3 in shell_points[index]:
				minimum = minf(minimum, local_normal.dot(point) + offset)
	if not is_finite(minimum):
		return
	var lift := (.003 - minimum) / (1.0 if terrain.split else normal.y)
	if lift < 0.0:
		var phase := animator.current_animation_position / maxf(.001, animator.current_animation_length)
		lift *= smoothstep(.75, 1.0, phase) if dead else 0.0
	terrain.live_lift = lift
	model.global_position.y += lift


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		sample_floor()
	return true


func begin_death_from(source: Node3D) -> float:
	global_transform = source.global_transform
	terrain.plane = source.terrain.plane
	terrain.split = source.terrain.split
	var continuing: bool = source.dead and source.current_clip == "Death"
	collapse_scale = source.ribbons.scale
	collapse_start = source.animator.current_animation_position if continuing else 0.0
	var speed := maxf(.001, absf(source.animator.get_playing_speed())) if continuing else 1.0
	current_clip = "Death"
	animator.play(current_clip, 0.0, speed)
	collapse_blend = minf(.12 * speed, animator.current_animation_length - collapse_start)
	animator.advance(0.0)
	animator.seek(collapse_start, true)
	action_remaining = maxf(0.0, animator.current_animation_length - collapse_start) / speed
	return action_remaining


func corpse_snapshot_floor() -> float:
	var floor := INF
	for index in shells.size():
		var space := global_transform.affine_inverse() * shells[index].global_transform
		for point: Vector3 in shell_points[index]:
			floor = minf(floor, (space * point).y)
	return floor
