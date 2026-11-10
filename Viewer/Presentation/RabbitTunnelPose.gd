# SPDX-License-Identifier: GPL-3.0-or-later
extends SkeletonModifier3D

const Rabbit := preload("res://Presentation/RabbitVisual.gd")
const Leg := preload("res://Presentation/FootContact.gd")
const END := 5.15

var rabbit: Rabbit
var elapsed := 0.0
var hips := -1
var spine := -1
var head := -1
var front: Array[PackedInt32Array] = []

func start(actor: Rabbit) -> void:
	rabbit = actor
	var rig := rabbit.skeleton
	hips = rig.find_bone("Hips")
	spine = rig.find_bone("Spine.001")
	head = rig.find_bone("Head")
	for side in ["L", "R"]:
		front.append(PackedInt32Array([rig.find_bone("FrontUpLeg_" + side),
			rig.find_bone("FrontLeg_" + side), rig.find_bone("FrontPaw_" + side)]))
	rabbit.current_clip = "Idle"
	rabbit.action_remaining = END
	rabbit.animator.speed_scale = 1.0
	rabbit.play("Idle", .16)
	rig.add_child(self)

func _process_modification_with_delta(delta: float) -> void:
	if rabbit.dead or rabbit.current_clip != "Idle" or elapsed >= END:
		queue_free()
		return
	elapsed += delta
	pose(elapsed)

func pose(seconds: float) -> void:
	var rig := get_skeleton()
	var blend := smoothstep(.16, .58, seconds)
	var descent := smoothstep(3.55, 4.93, seconds)
	var recovery := 1.0 - smoothstep(5.0, END, seconds)
	var forward := rabbit.global_basis.z.normalized()
	var right := rabbit.global_basis.x.normalized()
	var into_rig := rig.global_basis.inverse()
	var goals: Array[Vector3] = []
	for side in 2:
		var paw := rig.get_bone_global_pose(front[side][2]).origin
		var stroke := fposmod((seconds - .18) / .66 + .5 * side, 1.0)
		var reach := .5 - .5 * cos(stroke * TAU)
		var lift := sin(stroke * TAU) if stroke < .5 else 0.0
		var weight := blend * (1.0 - descent)
		goals.append(paw + into_rig * (forward * (.074 * reach - .021) + Vector3.UP * .048 * lift) * weight)
	turn(rig, spine, (into_rig * right).normalized(), (.24 * blend + .24 * descent) * recovery)
	turn(rig, head, (into_rig * right).normalized(), .16 * blend * recovery)
	for side in 2:
		place_front_paw(rig, front[side], goals[side], blend * (1.0 - descent) * recovery)
	var root := rig.get_bone_global_pose(hips)
	root.origin += into_rig * (forward * .145 - Vector3.UP * .50) * (descent * recovery)
	rig.set_bone_global_pose(hips, root)

func turn(rig: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	var joint := rig.get_bone_global_pose(bone)
	joint.basis = Basis(Quaternion(axis, angle)) * joint.basis
	rig.set_bone_global_pose(bone, joint)

func place_front_paw(rig: Skeleton3D, bones: PackedInt32Array, target: Vector3, weight: float) -> void:
	var upper := rig.get_bone_global_pose(bones[0]).origin
	var lower := rig.get_bone_global_pose(bones[1]).origin
	var paw := rig.get_bone_global_pose(bones[2]).origin
	var goal := paw.lerp(target, weight)
	aim_bone(rig, bones[0], bones[1], Leg.knee_target(upper, lower, paw, goal))
	aim_bone(rig, bones[1], bones[2], goal)

func aim_bone(rig: Skeleton3D, bone: int, child: int, goal: Vector3) -> void:
	var joint := rig.get_bone_global_pose(bone)
	var before := rig.get_bone_global_pose(child).origin - joint.origin
	var after := goal - joint.origin
	if minf(before.length_squared(), after.length_squared()) <= .00001:
		return
	joint.basis = Basis(Quaternion(before.normalized(), after.normalized())) * joint.basis
	rig.set_bone_global_pose(bone, joint)
