# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Dispatch := preload("res://Presentation/EnhancedCreatureActions.gd")
const Step := .22
const Tick := 1.0 / 60.0
const Forms := [98, 23]
const Gestures := {
	98: [[-12, 0, "hell_hound/FireBreath"]],
	23: [[2, 0, "DireWolfLowRecoil"], [5, 0, "DireWolfScentCheck"], [5, 1, "DireWolfShortHowl"],
		[8, 0, "DireWolfAlert"], [11, 0, "DireWolfForepawSnap"], [14, 0, "DireWolfQuietStand"]],
}

var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
var fitted := "--step-quadruped-candidate" in OS.get_cmdline_user_args()
var checked := 0
var gesture_samples := 0


class Avatar extends Node3D:
	var horse_visual: Node3D

	func receive_native_action(request: Dictionary) -> bool:
		return horse_visual.receive_action(request)


func _initialize() -> void:
	create_timer(180.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	if enhanced:
		assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
	if fitted:
		assert(load("res://Presentation/SourceStepQuadrupedProfile.gd").enable())
	var lower := board(Vector3(4, .2, 8))
	var upper := board(Vector3(4, .2, 8))
	upper.position = Vector3(2, Step - .1, 0)
	var results := {}
	for support: String in ["flat", "slope", "step"]:
		var split := support == "step"
		var normal := Vector3(.17, 1.0, -.11).normalized() if support == "slope" else Vector3.UP
		var middle := Vector3(-2, 0, 0) if split else Vector3.ZERO
		lower.transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), middle - .1 * normal)
		(lower.get_child(0).shape as BoxShape3D).size.x = 4.0 if split else 8.0
		upper.collision_layer = 1 if split else 0
		await physics_frame
		await physics_frame
		for body: int in Forms:
			var actor := Registry.create(body)
			root.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var surfaces := {}
			for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
				if mesh.skin != null and mesh.name != &"SourceContactReference":
					surfaces[mesh] = Ground.skin_points(mesh, actor.skeleton)
			assert(not surfaces.is_empty())
			if fitted and actor.animator.has_animation("Eat"):
				assert(actor.receive_action({"protocol": "classic", "action": 3}) and actor.current_clip == "Eat")
				actor.play_gait(true, 4.5)
				assert(actor.current_clip == "Run", "Movement must interrupt a feeding pose")
				actor.play_gait(false, 0.0)
			var row := {"feet": actor.contact.feet.size(), "surfaces": surfaces.keys().map(func(mesh): return str(mesh.name))}
			for heading: float in [PI * .5, PI * 1.5]:
				for clip: String in ["Walk", "Run"]:
					for phase: float in [0.0, .34, .68]:
						cross(actor, surfaces, clip, heading, phase, normal, split, row)
				if (body == 98 and fitted) or (body == 23 and enhanced):
					for x: float in ([-.18, .18] if split else [0.0]):
						for action: Array in Gestures.get(body, []):
							gesture(actor, surfaces, heading, x, normal, split, row, action)
			results["%s-%d" % [support, body]] = row
			print("STEP QUADRUPEDS ", support, " ", body, " ", JSON.stringify(row))
			actor.free()
	var mode := "enhanced" if enhanced else "classic"
	var path := "user://canines-terrain-%s-%s.json" % [mode, "candidate" if fitted else "baseline"]
	var report := FileAccess.open(path, FileAccess.WRITE)
	report.store_string(JSON.stringify({"poses": checked, "horn_poses": gesture_samples, "results": results}, "  "))
	report.close()
	print("STEP QUADRUPEDS: ", checked, " gait samples, ", gesture_samples, " gesture samples, ", mode)
	if fitted:
		for row: Dictionary in results.values():
			assert(float(row.get("moving_penetration", {}).get("value", INF)) <= -.002)
			assert(float(row.get("gesture_penetration", {}).get("value", -INF)) <= -.002)
	var expected_gestures := (2928 if enhanced else 0) + (488 if fitted else 0)
	quit(0 if checked == 4500 and gesture_samples == expected_gestures else 1)


func board(size: Vector3) -> StaticBody3D:
	var ground := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	ground.add_child(collision)
	root.add_child(ground)
	return ground


func pose(actor: Node3D, time: float) -> void:
	actor.animator.seek(time, true)
	actor._physics_process(Tick)
	actor.contact._process_modification_with_delta(Tick)
	actor.contact.modification_processed.emit()
	actor.skeleton.force_update_all_bone_transforms()


func cross(actor: Node3D, surfaces: Dictionary, clip: String, heading: float, start: float,
		normal: Vector3, split: bool, row: Dictionary) -> void:
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var span := 2.5
	var speed := 1.7 if clip == "Walk" else 4.5
	var frames := int(ceil(span / (speed * Tick)))
	var direction := 1.0 if heading < PI else -1.0
	var prior_phase := 0.0
	var prior := PackedVector3Array()
	var prior_lift := 0.0
	actor.rotation.y = heading
	actor.current_clip = clip
	player.play(clip, 0.0)
	player.advance(0.0)
	var joints := ["bip01 l foot", "bip01 r foot", "bip01 head", "bip01 r hand"]
	for index in frames + 1:
		var x := direction * lerpf(-span / 2.0, span / 2.0, index / float(frames))
		var y := Step * clampf(x + .5, 0.0, 1.0) if split else -normal.x * x / normal.y
		var anchor := Vector3(x, y, 0)
		actor.position = anchor
		var phase := fposmod(start + index * Tick / player.current_animation_length, 1.0)
		pose(actor, player.current_animation_length * phase)
		assert(actor.position == anchor and actor.native_hue == 0x8035)
		var details := {"clip": clip, "phase": phase, "x": x, "heading": heading}
		if fitted:
			var lift: float = actor.contact.lift
			maximum(row, "gait_lift", lift, details)
			if index > 0:
				maximum(row, "gait_lift_change", absf(lift - prior_lift), details)
			prior_lift = lift
		for mesh: MeshInstance3D in surfaces:
			if mesh.is_visible_in_tree():
				var gap := skin_gap(surfaces[mesh], rig, normal, split)
				assert(is_finite(gap))
				maximum(row, "moving_penetration", -gap, details.merged({"mesh": str(mesh.name)}))
		var joints_now := PackedVector3Array()
		for label: String in joints:
			var bone := rig.find_bone(label)
			assert(bone >= 0)
			var point := rig.to_global(rig.get_bone_global_pose(bone).origin) - anchor
			if phase < prior_phase:
				maximum(row, "loop_seam", prior[joints_now.size()].distance_to(point), details.merged({"joint": label}))
			joints_now.append(point)
		prior = joints_now
		prior_phase = phase
		checked += 1


func gesture(actor: Node3D, surfaces: Dictionary, heading: float, x: float,
		normal: Vector3, split: bool, row: Dictionary, action: Array) -> void:
	var player: AnimationPlayer = actor.animator
	actor.rotation.y = heading
	actor.position = Vector3(x, Step if x > 0.0 else 0.0, 0)
	var anchor := actor.position
	var avatar := Avatar.new()
	avatar.horse_visual = actor
	if actor.native_body == 98:
		assert(actor.receive_action(actor.BreathPacket))
	else:
		assert(Dispatch.dispatch(avatar, {"protocol": "new", "body": actor.native_body,
			"type": action[0], "subaction": 0, "variation": action[1]}, true, 0x40))
	avatar.free()
	var expected: String = action[2]
	assert(actor.current_clip == expected and not actor.dead)
	player.advance(.13)
	for index in 61:
		var phase := index / 60.0
		pose(actor, player.current_animation_length * phase)
		var details := {"clip": expected, "phase": phase, "x": x, "heading": heading}
		assert(actor.position == anchor and not actor.dead)
		for mesh: MeshInstance3D in surfaces:
			if mesh.is_visible_in_tree():
				maximum(row, "gesture_penetration", -skin_gap(surfaces[mesh], actor.skeleton, normal, split), details)
		gesture_samples += 1
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)


func skin_gap(skin: Dictionary, rig: Skeleton3D, normal: Vector3, split: bool) -> float:
	if not split:
		return Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, normal)
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
					point += matrices[surface.bindings[slot]] * surface.points[vertex] * weight
			minimum = minf(minimum, ground_gap(point, normal, split))
	return minimum


func ground_gap(point: Vector3, normal: Vector3, split: bool) -> float:
	return point.y - (Step if point.x > 0.0 else 0.0) if split else normal.dot(point)


func maximum(row: Dictionary, key: String, value: float, details: Dictionary) -> void:
	if value > float(row.get(key, {}).get("value", -INF)):
		row[key] = details.merged({"value": value})
