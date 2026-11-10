# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourcePreservingCreatureVisual.gd"

const Fall := preload("res://Presentation/SourceSpaceFallPlayback.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Limbs := preload("res://Presentation/FootContact.gd")

var fall := Fall.new()
var body_skin: Dictionary
var hammer_skin: Dictionary
var hammer_joint: int
var right_arm := PackedInt32Array()
var hammer_lift := 0.0

func _ready() -> void:
	super._ready()
	var hammer := model.find_child("EnhancedHammer", true, false) as MeshInstance3D
	body_skin = Ground.skin_points(model.find_child("Body", true, false), skeleton)
	hammer_skin = Ground.skin_points(hammer, skeleton)
	hammer_joint = hammer.skin.get_bind_bone(0)
	for name: String in ["bip01 r upperarm", "bip01 r forearm", "bip01 r hand"]:
		right_arm.append(skeleton.find_bone(name))
	animator.mixer_applied.connect(settle_fall)

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	release_hammer_lift()
	fall.accept_action(self)
	return true

func _physics_process(delta: float) -> void:
	if not dead:
		super._physics_process(delta)

func begin_death_from(source: Node3D) -> float:
	var duration := fall.begin_from_source(self, source, source.fall, Vector3.UP * source.hammer_lift)
	support_hammer()
	return duration

func release_hammer_lift() -> void:
	model.global_position.y -= hammer_lift
	hammer_lift = 0.0

func settle_fall() -> void:
	release_hammer_lift()
	if dead and not fall.plane.is_empty():
		fall.settle(self)
		support_hammer()

func support_hammer() -> void:
	release_hammer_lift()
	var normal: Vector3 = fall.plane.normal
	var gap := hammer_gap()
	if gap < 0.002:
		gap = roll_hammer(gap, normal)
	if gap < 0.002:
		lift_grip(normal * minf(0.20, 0.002 - gap))
		gap = minf(hammer_gap(), Ground.minimum_plane_gap(body_skin, skeleton, skeleton.global_transform,
			fall.plane.position, normal))
	hammer_lift = maxf(0.0, (0.002 - gap) / normal.y)
	model.global_position.y += hammer_lift
	update_landmarks()

func hammer_gap() -> float:
	return Ground.minimum_plane_gap(hammer_skin, skeleton, skeleton.global_transform, fall.plane.position, fall.plane.normal)

func lift_grip(displacement: Vector3) -> void:
	var upper := right_arm[0]
	var elbow := right_arm[1]
	var wrist := right_arm[2]
	var hand := skeleton.get_bone_global_pose(wrist)
	var target := hand.origin + skeleton.global_basis.inverse() * displacement
	var bend := Limbs.knee_target(skeleton.get_bone_global_pose(upper).origin,
		skeleton.get_bone_global_pose(elbow).origin, hand.origin, target)
	contact.aim(upper, elbow, bend)
	skeleton.force_update_all_bone_transforms()
	contact.aim(elbow, wrist, target)
	skeleton.force_update_all_bone_transforms()
	hand.origin = skeleton.get_bone_global_pose(wrist).origin
	skeleton.set_bone_global_pose(wrist, hand)
	skeleton.force_update_all_bone_transforms()

func roll_hammer(initial_gap: float, normal: Vector3) -> float:
	var original := skeleton.global_transform * skeleton.get_bone_global_pose(hammer_joint)
	var shaft := original.basis.y.slide(normal)
	if shaft.length_squared() < .001:
		return initial_gap
	shaft = shaft.normalized()
	var from := original.basis.orthonormalized()
	var rolled := Basis(normal, shaft, normal.cross(shaft))
	var scale := original.basis.get_scale()
	var posed := original
	posed.basis = rolled.scaled_local(scale)
	set_hammer_pose(posed)
	var rolled_gap := hammer_gap()
	if rolled_gap <= initial_gap:
		set_hammer_pose(original)
		return initial_gap
	if rolled_gap < .002:
		return rolled_gap

	# Use the smallest roll that clears the blade while the grip stays fixed.
	var lower := 0.0
	var upper := 1.0
	for i in 6:
		var weight := (lower + upper) * .5
		posed.basis = from.slerp(rolled, weight).scaled_local(scale)
		set_hammer_pose(posed)
		if hammer_gap() < .002:
			lower = weight
		else:
			upper = weight
	posed.basis = from.slerp(rolled, upper).scaled_local(scale)
	set_hammer_pose(posed)
	return hammer_gap()

func set_hammer_pose(world_pose: Transform3D) -> void:
	skeleton.set_bone_global_pose(hammer_joint, skeleton.global_transform.affine_inverse() * world_pose)
	skeleton.force_update_all_bone_transforms()

func corpse_snapshot_floor() -> float:
	if fall.plane.is_empty():
		return INF
	var local := global_transform.affine_inverse() * skeleton.global_transform
	return minf(fall.snapshot_floor(self), Ground.minimum_plane_gap(hammer_skin, skeleton, local, Vector3.ZERO, Vector3.UP))
