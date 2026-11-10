# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/EarthAssemblyActionsVisual.gd"

const Formation := "EarthStoneFormation"
const StoneFall := "EarthStoneFall"
const FallDuration := .48
var gesture_ground := preload("res://Presentation/ArchiveGestureGround.gd").new()
var pieces: Node3D
var living_mesh: MeshInstance3D
var piece_points := {}
var formation_shift := Vector3.ZERO
var falling_pieces := {}
var fall_plane := {}

func _ready() -> void:
	super._ready()
	pieces = model.get_node("AssemblyPieces")
	living_mesh = model.find_child("Body", true, false)
	for piece: MeshInstance3D in pieces.get_children():
		piece_points[piece] = piece.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	gesture_ground.bind(self)
	animator.mixer_applied.connect(adjust_formation)

func _physics_process(delta: float) -> void:
	gesture_ground.release(self)
	super._physics_process(delta)

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if current_clip == Formation:
		contact.enabled = false
		living_mesh.hide()
		pieces.show()
		for piece: MeshInstance3D in piece_points:
			piece.visible = piece.name == &"Piece13"
	else:
		restore_formation()
	return true

func restore_formation() -> void:
	model.position -= formation_shift
	formation_shift = Vector3.ZERO
	if current_clip != Formation:
		pieces.hide()
		living_mesh.show()

func adjust_formation() -> void:
	if current_clip == StoneFall:
		return
	restore_formation()
	if current_clip != Formation or dead:
		return
	var hit := stone_support()
	if hit.is_empty():
		return
	var normal: Vector3 = hit.normal
	var contact_point: Vector3 = hit.position
	var gap := INF
	if pieces.visible:
		for piece: MeshInstance3D in piece_points:
			if not piece.visible:
				continue
			gap = minf(gap, stone_gap(piece, contact_point, normal, piece.global_transform))
	else:
		skeleton.force_update_all_bone_transforms()
		gap = Ground.minimum_plane_gap(gesture_ground.skin, skeleton, skeleton.global_transform, contact_point, normal)
	if gap < .002:
		var prior := model.position
		model.global_position += Vector3.UP * ((.002 - gap) / normal.y)
		formation_shift = model.position - prior

func stone_support() -> Dictionary:
	var support := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * .7,
		global_position - Vector3.UP * 1.6, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(support)
	return hit if not hit.is_empty() and hit.normal.y >= .75 else {}

func stone_gap(piece: MeshInstance3D, point: Vector3, normal: Vector3, space: Transform3D) -> float:
	var direction := space.basis.transposed() * normal
	var offset := (space.origin - point).dot(normal)
	var gap := INF
	for vertex: Vector3 in piece_points[piece]:
		gap = minf(gap, vertex.dot(direction) + offset)
	return gap

func begin_death_from(source: Node3D) -> float:
	if source.current_clip != Formation or not source.pieces.visible:
		return super.begin_death_from(source)
	global_transform = source.global_transform
	animator.stop(true)
	current_clip = StoneFall
	action_remaining = 0.0
	living_mesh.hide()
	pieces.show()
	fall_plane = stone_support()
	if fall_plane.is_empty():
		fall_plane = {"position": global_position, "normal": Vector3.UP}
	var clip := animator.get_animation(Formation)
	var animation_root := animator.get_node(animator.root_node)
	for piece: MeshInstance3D in piece_points:
		var original: MeshInstance3D = source.pieces.get_node(NodePath(piece.name))
		piece.visible = original.visible
		if not piece.visible:
			continue
		var path := animation_root.get_path_to(piece)
		var rotation := clip.find_track(path, Animation.TYPE_ROTATION_3D)
		var position := clip.find_track(path, Animation.TYPE_POSITION_3D)
		var target := Transform3D(Basis(clip.track_get_key_value(rotation, 0) as Quaternion),
			clip.track_get_key_value(position, 0))
		falling_pieces[piece] = [original.transform, target]
	advance_stone_fall(0.0)
	create_tween().tween_method(advance_stone_fall, 0.0, 1.0, FallDuration)
	return FallDuration

func advance_stone_fall(weight: float) -> void:
	var blend := smoothstep(0.0, 1.0, weight)
	var normal: Vector3 = fall_plane.normal
	for piece: MeshInstance3D in falling_pieces:
		var poses: Array = falling_pieces[piece]
		piece.transform = poses[0].interpolate_with(poses[1], blend)
		var gap := stone_gap(piece, fall_plane.position, normal, piece.global_transform)
		var lift := .002 - gap
		if lift < 0.0:
			lift *= smoothstep(.69, 1.0, weight)
		piece.global_position += Vector3.UP * (lift / normal.y)

func corpse_snapshot_floor() -> float:
	if current_clip != StoneFall:
		return super.corpse_snapshot_floor()
	var space := global_transform.affine_inverse()
	var floor := INF
	for piece: MeshInstance3D in falling_pieces:
		floor = minf(floor, stone_gap(piece, Vector3.ZERO, Vector3.UP, space * piece.global_transform))
	return floor
