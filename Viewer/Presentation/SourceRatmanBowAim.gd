# SPDX-License-Identifier: GPL-3.0-or-later
extends SkeletonModifier3D

const ArmFit := preload("res://Presentation/CentaurBowRelease.gd")
const ReleaseTime := .12
const RecoveryTime := .46
signal released(origin: Vector3)
var archer: Node3D
var left: PackedInt32Array
var right: PackedInt32Array
var chest: int
var neck: int
var target := Vector3.ZERO
var elapsed := RecoveryTime


func bind(visual: Node3D) -> void:
	archer = visual
	var rig: Skeleton3D = visual.skeleton
	left = arm(rig, "l")
	right = arm(rig, "r")
	chest = rig.find_bone("bip01 spine2")
	neck = rig.find_bone("bip01 neck")
	assert(chest >= 0 and neck >= 0 and not left.has(-1) and not right.has(-1))
	rig.add_child(self)


func arm(rig: Skeleton3D, side: String) -> PackedInt32Array:
	var joints := PackedInt32Array()
	for name: String in ["upperarm", "forearm", "hand"]:
		joints.append(rig.find_bone("bip01 %s %s" % [side, name]))
	joints.append(rig.find_bone("cp_grasp_%shand" % side))
	return joints


func start(destination: Vector3) -> void:
	target = destination
	elapsed = 0.0


func _process_modification_with_delta(delta: float) -> void:
	if elapsed >= RecoveryTime:
		return
	if not archer.bow_release_available():
		elapsed = RecoveryTime
		return
	var previous := elapsed
	elapsed = minf(elapsed + delta, RecoveryTime)
	var weight := smoothstep(0.0, .075, elapsed) * (1.0 - smoothstep(.18, RecoveryTime, elapsed))
	var draw := smoothstep(0.0, .075, elapsed) * (1.0 - smoothstep(ReleaseTime, .17, elapsed))
	var rig := get_skeleton()
	var up := Vector3.UP
	var forward := archer.global_basis.z.slide(up).normalized()
	var shoulder := rig.to_global(rig.get_bone_global_pose(left[0]).origin)
	var toward := target - shoulder
	var horizontal := toward.slide(up)
	var angle := 0.0
	if horizontal.length_squared() > .001:
		angle = clampf(forward.signed_angle_to(horizontal.normalized(), up), -.95, .95)
	var aim := forward.rotated(up, angle)
	var pitch := clampf(atan2(toward.y, horizontal.length()), -.32, .38)
	var flight := (aim * cos(pitch) + up * sin(pitch)).normalized()
	var across := up.cross(aim)
	# Turn the shoulder line through the shot, while the neck keeps facing the target.
	var turn := angle * .55 - .58
	var local_up := (rig.global_basis.inverse() * up).normalized()
	yaw_joint(rig, chest, local_up, turn * weight)
	yaw_joint(rig, neck, local_up, (angle - turn) * weight)
	shoulder = rig.to_global(rig.get_bone_global_pose(left[0]).origin)
	var palm := shoulder + flight * .38 - across * .065 - up * .11
	ArmFit.place_arm(rig, left, palm, aim * .20 - up, across * .4 - up * .75, weight, 1.0)
	var recoil := smoothstep(ReleaseTime, .18, elapsed)
	var draw_hand: Vector3 = archer.bow_draw_target(flight, across, .19 * draw + .23 * recoil)
	ArmFit.place_arm(rig, right, draw_hand, aim * .75 - up * .17, -across - aim * .55, weight, 1.0)
	archer.pose_bow_release(flight, across, weight, draw)
	if previous < ReleaseTime and elapsed >= ReleaseTime:
		released.emit(archer.bow_arrow_origin())


func yaw_joint(rig: Skeleton3D, joint: int, axis: Vector3, radians: float) -> void:
	var pose := rig.get_bone_global_pose(joint)
	pose.basis = Basis(axis, radians) * pose.basis
	rig.set_bone_global_pose(joint, pose)
