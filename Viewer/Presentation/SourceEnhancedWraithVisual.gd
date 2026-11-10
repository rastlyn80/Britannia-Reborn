# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/WraithActionsVisual.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Assembly := "WraithReconstitute"
const Scatter := "WraithScatterFall"
const ScatterSeconds := .52
const HoverClips := ["WraithSurge", "WraithVeilInspect", "WraithVeilDive", "WraithWindborneReach", Assembly]

var displayed_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var pieces: Node3D
var living_mesh: MeshInstance3D
var piece_points := {}
var living_points := {}
var display_lift := Vector3.ZERO
var fall_plane := {}
var falling_parts := {}

func _ready() -> void:
	super._ready()
	pieces = model.get_node("AssemblyPieces")
	living_mesh = model.find_child("Body", true, false)
	living_points = Ground.skin_points(living_mesh, skeleton)
	for part: MeshInstance3D in pieces.get_children():
		piece_points[part] = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	animator.mixer_applied.connect(adjust_display)
	animator.mixer_applied.connect(displayed_fall.settle.bind(self))

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	reset_display_lift()
	if current_clip in HoverClips:
		contact.enabled = false
	if current_clip == Assembly:
		living_mesh.hide()
		pieces.show()
		for part: MeshInstance3D in piece_points:
			part.visible = part.name != &"Veil"
	else:
		restore_living_mesh()
	return true

func reset_display_lift() -> void:
	model.position -= display_lift
	display_lift = Vector3.ZERO

func restore_living_mesh() -> void:
	pieces.hide()
	living_mesh.show()

func adjust_display() -> void:
	reset_display_lift()
	if current_clip not in [Assembly, Scatter]:
		restore_living_mesh()
	if dead or current_clip not in HoverClips:
		return
	var support := support_plane()
	if support.is_empty():
		return
	var point: Vector3 = support.position
	var normal: Vector3 = support.normal
	var gap := INF
	if pieces.visible:
		for part: MeshInstance3D in piece_points:
			if part.visible:
				gap = minf(gap, part_gap(part, point, normal, part.global_transform))
	else:
		skeleton.force_update_all_bone_transforms()
		gap = Ground.minimum_plane_gap(living_points, skeleton, skeleton.global_transform, point, normal)
	if gap < .002:
		var prior := model.position
		model.global_position += Vector3.UP * ((.002 - gap) / normal.y)
		display_lift = model.position - prior

func support_plane() -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * .7,
		global_position - Vector3.UP * 1.6, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return hit if not hit.is_empty() and hit.normal.y >= .75 else {}

func part_gap(part: MeshInstance3D, point: Vector3, normal: Vector3, space: Transform3D) -> float:
	var direction := space.basis.transposed() * normal
	var offset := (space.origin - point).dot(normal)
	var gap := INF
	for vertex: Vector3 in piece_points[part]:
		gap = minf(gap, vertex.dot(direction) + offset)
	return gap

func begin_death_from(source: Node3D) -> float:
	if source.current_clip == Assembly and source.pieces.visible:
		return begin_scatter_from(source)
	if source.current_clip in HoverClips:
		return displayed_fall.begin_from_source(self, source, source.displayed_fall, false)
	return super.begin_death_from(source)

func begin_scatter_from(source: Node3D) -> float:
	global_transform = source.global_transform
	animator.stop(true)
	current_clip = Scatter
	action_remaining = 0.0
	living_mesh.hide()
	pieces.show()
	fall_plane = support_plane()
	if fall_plane.is_empty():
		fall_plane = {"position": global_position, "normal": Vector3.UP}
	var animation_root := animator.get_node(animator.root_node)
	var clip := animator.get_animation(Assembly)
	for part: MeshInstance3D in piece_points:
		var original: MeshInstance3D = source.pieces.get_node(NodePath(part.name))
		part.visible = original.visible
		if not part.visible:
			continue
		var path := animation_root.get_path_to(part)
		var rotation := clip.find_track(path, Animation.TYPE_ROTATION_3D)
		var position := clip.find_track(path, Animation.TYPE_POSITION_3D)
		var size := clip.find_track(path, Animation.TYPE_SCALE_3D)
		var basis := Basis(clip.track_get_key_value(rotation, 0) as Quaternion)
		var target := Transform3D(basis.scaled_local(clip.track_get_key_value(size, 0)),
			clip.track_get_key_value(position, 0))
		falling_parts[part] = [original.transform, target]
	advance_scatter(0.0)
	create_tween().tween_method(advance_scatter, 0.0, 1.0, ScatterSeconds)
	return ScatterSeconds

func advance_scatter(progress: float) -> void:
	var blend := smoothstep(0.0, 1.0, progress)
	var normal: Vector3 = fall_plane.normal
	for part: MeshInstance3D in falling_parts:
		var poses: Array = falling_parts[part]
		part.transform = poses[0].interpolate_with(poses[1], blend)
		var correction := .002 - part_gap(part, fall_plane.position, normal, part.global_transform)
		if correction < 0.0:
			correction *= smoothstep(.68, 1.0, progress)
		part.global_position += Vector3.UP * (correction / normal.y)

func corpse_snapshot_floor() -> float:
	if current_clip == Scatter:
		var local := global_transform.affine_inverse()
		var floor := INF
		for part: MeshInstance3D in falling_parts:
			floor = minf(floor, part_gap(part, Vector3.ZERO, Vector3.UP, local * part.global_transform))
		return floor
	if not displayed_fall.plane.is_empty():
		return displayed_fall.snapshot_floor(self)
	return super.corpse_snapshot_floor()
