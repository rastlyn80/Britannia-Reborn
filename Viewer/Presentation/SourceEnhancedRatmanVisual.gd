# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureVisual.gd"

const Fall := preload("res://Presentation/SourceSpaceFallPlayback.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const LiveGround := preload("res://Presentation/ArchiveGestureGround.gd")
const Clearance := .002

var fall := Fall.new()
var support := LiveGround.new()
var axe_skin: Dictionary
var axe_joint: int
var axe_lift := Vector3.ZERO

func _ready() -> void:
	super._ready()
	var axe := model.find_child("EnhancedRatmanAxe", true, false) as MeshInstance3D
	axe_skin = Ground.skin_points(axe, skeleton)
	axe_joint = axe.skin.get_bind_bone(0)
	# Remove the previous axe lift before the common body correction is restored.
	animator.mixer_applied.connect(release_axe_lift)
	contact.modification_processed.connect(release_axe_lift)
	support.bind(self)
	contact.modification_processed.connect(settle_living_axe)
	animator.mixer_applied.connect(settle_fall)

func set_hue(value: int) -> void:
	super.set_hue(value)
	if model != null:
		var axe := model.find_child("EnhancedRatmanAxe", true, false) as MeshInstance3D
		if axe != null:
			# A mobile hue belongs to the body. This visual prop has no item hue.
			axe.set_surface_override_material(0, null)

func _physics_process(delta: float) -> void:
	if not dead:
		release_axe_lift()
		support.release(self)
		super._physics_process(delta)

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	release_axe_lift()
	support.release(self)
	fall.accept_action(self)
	return true

func begin_death_from(source: Node3D) -> float:
	var live_shift: Vector3 = source.axe_lift
	if source.support.applied:
		live_shift = source.model.position - source.support.restore_pose.origin
	var duration := fall.begin_from_source(self, source, source.fall, live_shift)
	if not source.dead and source.current_clip == "RatmanAxeSomersault":
		fall.blend_length = minf(.28, duration)
	release_axe_lift()
	support_axe(fall.plane)
	return duration

func release_axe_lift() -> void:
	model.position -= axe_lift
	axe_lift = Vector3.ZERO

func settle_living_axe() -> void:
	if not dead and not contact.contacts.is_empty():
		support_axe(contact.contacts.values()[0])

func settle_fall() -> void:
	if dead and not fall.plane.is_empty():
		fall.settle(self)
		support_axe(fall.plane)

func support_axe(plane: Dictionary) -> void:
	var normal: Vector3 = plane.normal
	if normal.y < .75:
		return
	skeleton.force_update_all_bone_transforms()
	var gap := axe_gap(plane)
	if gap < Clearance:
		gap = roll_axe(plane, gap)
	if gap < Clearance:
		var prior: Vector3 = model.position
		model.global_position.y += (Clearance - gap) / normal.y
		axe_lift = model.position - prior

func roll_axe(plane: Dictionary, initial_gap: float) -> float:
	var space := skeleton.global_transform
	var original := space * skeleton.get_bone_global_pose(axe_joint)
	var normal: Vector3 = plane.normal
	var shaft := original.basis.y.slide(normal)
	if shaft.length_squared() < .001:
		return initial_gap
	shaft = shaft.normalized()
	var from := original.basis.orthonormalized()
	var level := Basis(normal, shaft, normal.cross(shaft))
	if from.x.dot(normal) < 0.0:
		level = Basis(-normal, shaft, -normal.cross(shaft))
	var pose := original
	var scale := original.basis.get_scale()
	pose.basis = level.scaled_local(scale)
	set_axe_pose(space, pose)
	var gap := axe_gap(plane)
	if gap <= initial_gap:
		set_axe_pose(space, original)
		return initial_gap
	if gap < Clearance:
		return gap
	var lower := 0.0
	var upper := 1.0
	for index in 6:
		var weight := (lower + upper) * .5
		pose.basis = from.slerp(level, weight).scaled_local(scale)
		set_axe_pose(space, pose)
		if axe_gap(plane) < Clearance:
			lower = weight
		else:
			upper = weight
	pose.basis = from.slerp(level, upper).scaled_local(scale)
	set_axe_pose(space, pose)
	return axe_gap(plane)

func set_axe_pose(space: Transform3D, pose: Transform3D) -> void:
	skeleton.set_bone_global_pose(axe_joint, space.affine_inverse() * pose)
	skeleton.force_update_all_bone_transforms()

func axe_gap(plane: Dictionary) -> float:
	return Ground.minimum_plane_gap(axe_skin, skeleton, skeleton.global_transform, plane.position, plane.normal)

func corpse_snapshot_floor() -> float:
	if fall.plane.is_empty():
		return INF
	var local := global_transform.affine_inverse() * skeleton.global_transform
	return minf(fall.snapshot_floor(self), Ground.minimum_plane_gap(axe_skin, skeleton, local, Vector3.ZERO, Vector3.UP))
