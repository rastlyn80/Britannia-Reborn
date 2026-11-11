# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/ArchiveGestureVisual.gd"

const Floor := preload("res://Presentation/SourceGroundLookup.gd")
const Quiet := "CrystalQuietStill"
const Assembly := "CrystalShardAssembly"
const Join := .74
const FragmentFall := "CrystalFragmentFall"
const FragmentFallTime := .58

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var fitted_transform := Transform3D.IDENTITY
var supported := false
var quiet_mode := false
var body_mesh: MeshInstance3D
var fragments: Node3D
var fragment_points := {}
var fragment_starts := {}
var fragment_plane := {}


func _ready() -> void:
	super._ready()
	body_mesh = model.find_children("*", "MeshInstance3D", true, false)[0]
	body_mesh.set_meta("optional_corpse_visual_prop", true)
	fragments = model.get_node("CrystalFragments")
	for part: MeshInstance3D in fragments.get_children():
		part.set_meta("corpse_material_source", body_mesh.name)
		fragment_points[part] = part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	fitted_fall.skin = ground_gesture.skin
	contact.modification_processed.disconnect(ground_gesture.support.bind(self))
	contact.modification_processed.connect(support_retained_gesture)
	animator.get_animation(Quiet).loop_mode = Animation.LOOP_LINEAR
	animator.mixer_applied.connect(settle_fitted)


func set_native_combat_flags(flags: int) -> void:
	quiet_mode = flags >= 0 and (flags & 0x40) == 0


func play_gait(moving: bool, speed: float) -> void:
	if moving or not quiet_mode:
		super.play_gait(moving, speed)
	elif not dead and action_remaining <= 0.0 and current_clip != Quiet:
		current_clip = Quiet
		animator.speed_scale = 1.0
		play(Quiet, .16)
	if is_fitted():
		contact.enabled = false
	if current_clip != Assembly and not dead:
		show_fragments(false)


func receive_action(request: Dictionary) -> bool:
	release_fitted()
	if not super.receive_action(request):
		return false
	show_fragments(current_clip == Assembly)
	if is_fitted():
		contact.enabled = false
	return true


func _physics_process(delta: float) -> void:
	if is_fitted():
		settle_fitted()
	elif fitted_fall.plane.is_empty():
		super._physics_process(delta)


func is_fitted() -> bool:
	return not dead and current_clip in entry.get("archive_grounded_gestures", [])


func support_retained_gesture() -> void:
	if not is_fitted():
		ground_gesture.support(self)


func release_fitted() -> void:
	if supported:
		model.transform = fitted_transform
		supported = false


func settle_fitted() -> void:
	release_fitted()
	if current_clip == FragmentFall:
		return
	if not fitted_fall.plane.is_empty():
		show_fragments(false)
		fitted_fall.settle(self)
	elif is_fitted():
		var split := current_clip == Assembly and animator.assigned_animation == Assembly \
			and animator.current_animation_position < animator.current_animation_length * Join
		show_fragments(split)
		var floor := fitted_fall.floor_under(self)
		var normal: Vector3 = floor.normal
		fitted_transform = model.transform
		supported = true
		var tilt := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
		model.basis = (tilt * source_model_basis).scaled_local(fitted_transform.basis.get_scale())
		skeleton.force_update_all_bone_transforms()
		var gap := fragment_gap(floor.position, normal) if split else Floor.minimum_plane_gap(
			fitted_fall.skin, skeleton, skeleton.global_transform, floor.position, normal)
		model.global_position.y += (.003 - gap) / normal.y


func show_fragments(split: bool) -> void:
	fragments.visible = split
	body_mesh.visible = not split


func fragment_gap(point: Vector3, normal: Vector3, to_space := Transform3D.IDENTITY) -> float:
	var gap := INF
	for part: MeshInstance3D in fragment_points:
		gap = minf(gap, piece_gap(part, point, normal, to_space * part.global_transform))
	return gap


func piece_gap(part: MeshInstance3D, point: Vector3, normal: Vector3, pose: Transform3D) -> float:
	var gap := INF
	var direction := pose.basis.transposed() * normal
	var offset := (pose.origin - point).dot(normal)
	for vertex: Vector3 in fragment_points[part]:
		gap = minf(gap, vertex.dot(direction) + offset)
	return gap


func begin_death_from(source: Node3D) -> float:
	if source.current_clip == Assembly and source.fragments.visible:
		global_transform = source.global_transform
		model.transform = source.model.transform
		animator.stop(true)
		current_clip = FragmentFall
		show_fragments(true)
		fragment_plane = fitted_fall.floor_under(source)
		for part: MeshInstance3D in fragment_points:
			var previous: MeshInstance3D = source.fragments.get_node(NodePath(part.name))
			part.global_transform = previous.global_transform
			fragment_starts[part] = part.global_transform
		create_tween().tween_method(settle_fragment_fall, 0.0, 1.0, FragmentFallTime)
		return FragmentFallTime
	if source.is_fitted():
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	play("Death", .08)
	return animator.get_animation("Death").length


func settle_fragment_fall(phase: float) -> void:
	var point: Vector3 = fragment_plane.position
	var normal: Vector3 = fragment_plane.normal
	var blend := smoothstep(0.0, 1.0, phase)
	for part: MeshInstance3D in fragment_starts:
		var from: Transform3D = fragment_starts[part]
		var turn := .24 * sin(float(part.get_index()) * 2.4)
		var target := Transform3D(Basis(normal, turn) * from.basis, from.origin)
		var outward := (from.origin - global_position).slide(normal).normalized()
		target.origin += outward * .16
		part.global_transform = from.interpolate_with(target, blend)
		var delta := .003 - piece_gap(part, point, normal, part.global_transform)
		part.global_position += Vector3.UP * (minf(delta, 0.0) * blend + maxf(delta, 0.0)) / normal.y


func corpse_snapshot_floor() -> float:
	if current_clip == FragmentFall:
		return fragment_gap(Vector3.ZERO, Vector3.UP, global_transform.affine_inverse())
	return NAN if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
