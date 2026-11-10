# SPDX-License-Identifier: GPL-3.0-or-later
extends SkeletonModifier3D

const BowVisual := preload("res://Presentation/CentaurBowVisual.gd")
const RELEASE_TIME := .09
const RECOVER_TIME := .45
# Third Dawn bow coordinates. Put the shaft just above and beside the grip.
const ARROW_REST := Vector3(-.033, .025, .114)

var archer: BowVisual
var left: PackedInt32Array
var right: PackedInt32Array
var head: int
var destination: Vector3
var elapsed := RECOVER_TIME

func bind(actor: BowVisual) -> void:
	archer = actor
	var rig := archer.skeleton
	left = arm(rig, "2")
	right = arm(rig, "1")
	head = rig.find_bone("bip01 head")
	rig.add_child(self)

func arm(rig: Skeleton3D, chain: String) -> PackedInt32Array:
	var bones := PackedInt32Array()
	for joint in range(1, 5):
		bones.append(rig.find_bone("bip01 ponytail%s%d" % [chain, joint]))
	return bones

func start(target: Vector3) -> void:
	destination = target
	elapsed = 0.0

func available() -> bool:
	return is_instance_valid(archer) and not archer.dead and archer.bow_id != 0 and is_instance_valid(archer.bow)

func arrow_rest() -> Vector3:
	return archer.bow.to_global(ARROW_REST)

func _process_modification_with_delta(delta: float) -> void:
	if elapsed >= RECOVER_TIME:
		return
	if not available():
		elapsed = RECOVER_TIME
		return
	elapsed = minf(elapsed + delta, RECOVER_TIME)
	var weight := smoothstep(0.0, RELEASE_TIME, elapsed) * (1.0 - smoothstep(.16, RECOVER_TIME, elapsed))
	var recoil := smoothstep(RELEASE_TIME, .17, elapsed)
	pose_release(weight, recoil)

func pose_release(weight: float, recoil: float) -> void:
	var rig := get_skeleton()
	var forward := archer.global_basis.z
	forward = Vector3(forward.x, 0.0, forward.z).normalized()
	var up := Vector3.UP
	var shoulder := rig.to_global(rig.get_bone_global_pose(left[0]).origin)
	var to_target := destination - shoulder
	var heading := Vector3(to_target.x, 0.0, to_target.z).normalized()
	var yaw := clampf(forward.signed_angle_to(heading, up), -.85, .85) if heading != Vector3.ZERO else 0.0
	var aim := forward.rotated(up, yaw)
	var across := up.cross(aim)
	var pitch := clampf(atan2(to_target.y, Vector2(to_target.x, to_target.z).length()), -.27, .27)
	var flight := (aim * cos(pitch) + up * sin(pitch)).normalized()
	var palm := shoulder + flight * (.52 - .045 * recoil) + across * .04 - up * .08
	var face := rig.to_global(rig.get_bone_global_pose(head).origin)
	var draw := face - across * (.15 + .035 * recoil) + aim * (.15 - .16 * recoil) - up * .10
	place_arm(rig, left, palm, aim * .28 - up, across * .4 - up * .7 - aim * .2, weight)
	place_arm(rig, right, draw, aim * .85 - up * .15, -across - aim * .65 + up * .12, weight)

	# The existing attachment owns the grip, visibility and hue. Only its
	# rotation changes during the release, and the grip stays on the palm.
	archer.sync_bow()
	var upright := Basis(across, -flight, flight.cross(across))
	var basis := archer.bow.global_basis.slerp(upright, weight)
	archer.bow.global_transform = Transform3D(basis, archer.left_palm() - basis * BowVisual.BOW_GRIP)

func place_arm(rig: Skeleton3D, bones: PackedInt32Array, palm: Vector3, knuckles: Vector3, elbow_hint: Vector3, weight: float) -> void:
	var shoulder := rig.get_bone_global_pose(bones[0]).origin
	var elbow := rig.get_bone_global_pose(bones[1]).origin
	var wrist := rig.get_bone_global_pose(bones[2]).origin
	var fingers := rig.get_bone_global_pose(bones[3]).origin
	var into_rig := rig.global_basis.inverse()
	var knuckle_axis := (into_rig * knuckles).normalized()
	var target := rig.to_local(palm) - knuckle_axis * wrist.distance_to(fingers) * .46
	var arm := target - shoulder
	var a := shoulder.distance_to(elbow)
	var b := elbow.distance_to(wrist)
	var reach := clampf(arm.length(), absf(a - b) + .001, a + b - .001)
	var axis := arm.normalized()
	var pole := (into_rig * elbow_hint).slide(axis).normalized()
	var along := (a * a - b * b + reach * reach) / (2.0 * reach)
	var bend := shoulder + axis * along + pole * sqrt(maxf(0.0, a * a - along * along))
	var start: Array[Quaternion] = []
	for joint in 3:
		start.append(rig.get_bone_pose_rotation(bones[joint]))
	aim_bone(rig, bones[0], bones[1], bend)
	aim_bone(rig, bones[1], bones[2], shoulder + axis * reach)
	aim_bone(rig, bones[2], bones[3], rig.get_bone_global_pose(bones[2]).origin + knuckle_axis)
	for joint in 3:
		var fitted := rig.get_bone_pose_rotation(bones[joint])
		rig.set_bone_pose_rotation(bones[joint], start[joint].slerp(fitted, weight))

func aim_bone(rig: Skeleton3D, bone: int, child: int, target: Vector3) -> void:
	var pose := rig.get_bone_global_pose(bone)
	var from := rig.get_bone_global_pose(child).origin - pose.origin
	var to := target - pose.origin
	if minf(from.length_squared(), to.length_squared()) > .000001:
		pose.basis = Basis(Quaternion(from.normalized(), to.normalized())) * pose.basis
		rig.set_bone_global_pose(bone, pose)
