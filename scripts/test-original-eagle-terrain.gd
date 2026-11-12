# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Profile := preload("res://Presentation/SourceOriginalEagleProfile.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Step := .22
const Motions := ["Idle", "Walk", "Attack", "Eat", "Fidget", "TakeOff", "Fly", "Land", "AirAttack", "AirEagleWingBeat"]


func _initialize() -> void:
	create_timer(110.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	if not Profile.enable():
		quit(1)
		return
	var lower := floor_box()
	var upper := floor_box()
	upper.position = Vector3(2, Step - .1, 0)
	var results := {}
	var checked := 0
	for support: String in ["flat", "slope", "step"]:
		var split := support == "step"
		var normal := Vector3(.17, 1.0, -.11).normalized() if support == "slope" else Vector3.UP
		var middle := Vector3(-2, 0, 0) if split else Vector3.ZERO
		lower.transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), middle - .1 * normal)
		(lower.get_child(0).shape as BoxShape3D).size.x = 4.0 if split else 8.0
		upper.collision_layer = 1 if split else 0
		await physics_frame
		await physics_frame
		for clip: String in Motions:
			var worst := {"gap": INF}
			var lift_change := 0.0
			for x: float in ([-.48, -.21, -.03, .15, .46] if split else [0.0]):
				for heading: float in [PI * .5, PI * 1.5]:
					var actor := Registry.create(5)
					root.add_child(actor)
					actor.set_process(false)
					actor.set_physics_process(false)
					actor.apply_identity(5, 0x8035)
					var rig: Skeleton3D = actor.skeleton
					var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
					var skin := Ground.skin_points(mesh, rig)
					var player: AnimationPlayer = actor.animator
					player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
					var anchor := Vector3(x, Step if split and x > 0.0 else 0.0, 0)
					actor.position = anchor
					actor.rotation.y = heading
					actor.current_clip = clip
					actor.flight_state = "air" if clip in ["Fly", "AirAttack", "AirEagleWingBeat"] else "ground"
					actor._physics_process(1.0 / 60.0)
					player.play(clip, 0.0)
					player.advance(0.0)
					var previous_y := INF
					for frame in 31:
						var phase := frame / 30.0
						player.seek(player.current_animation_length * phase, true)
						actor._physics_process(1.0 / 60.0)
						rig.force_update_all_bone_transforms()
						var gap := step_gap(skin, rig) if split else Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, normal)
						assert(actor.position == anchor and actor.native_hue == 0x8035 and is_finite(gap))
						if gap < worst.gap:
							worst = {"gap": gap, "x": x, "phase": phase, "heading": heading}
						var current_y: float = actor.model.global_position.y
						if is_finite(previous_y):
							lift_change = maxf(lift_change, absf(current_y - previous_y))
						previous_y = current_y
						checked += 1
					actor.free()
			results[support + ":" + clip] = worst.merged({"maximum_lift_change": lift_change})
	var minimum := INF
	var lift := 0.0
	for result: Dictionary in results.values():
		minimum = minf(minimum, result.gap)
		lift = maxf(lift, result.maximum_lift_change)
	assert(minimum > .0028 and lift < .18)
	print("EAGLE TERRAIN: ", checked, " full-skin poses, minimum gap ", minimum, ", largest model shift ", lift)
	quit(0 if checked == 4340 else 1)


func floor_box() -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, .2, 8)
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	return body


func step_gap(skin: Dictionary, rig: Skeleton3D) -> float:
	var matrices: Array[Transform3D] = []
	for index in skin.bones.size():
		matrices.append(rig.global_transform * rig.get_bone_global_pose(skin.bones[index]) * skin.bind_poses[index])
	var minimum := INF
	for surface: Dictionary in skin.surfaces:
		for vertex in surface.points.size():
			var point := Vector3.ZERO
			for influence in surface.stride:
				var slot: int = vertex * surface.stride + influence
				var weight: float = surface.weights[slot]
				if weight > 0.0:
					point += (matrices[surface.bindings[slot]] * surface.points[vertex]) * weight
			minimum = minf(minimum, point.y - (Step if point.x >= 0.0 else 0.0))
	return minimum
