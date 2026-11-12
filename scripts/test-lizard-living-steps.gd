# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Profile := preload("res://Presentation/SourceLizardLivingTerrainProfile.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Height := .22
const Clips := ["Idle", "Walk", "Run", "Fidget", "Pillage", "Hit"]
var samples := 0
var split_stances := 0
var worst := {}
var largest_lift := 0.0
var worst_lift := {}


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	assert(Profile.enable())
	floor_box(-2.0, 0.0)
	floor_box(2.0, Height)
	await physics_frame
	await physics_frame
	for body: int in [35, 36]:
		for x: float in [-.36, -.14, .14, .36]:
			for heading: float in [0.0, PI * .5, PI, PI * 1.5]:
				scan(body, x, heading)
	print("ARMED LIZARD LIVING STEPS: ", samples, " poses, ", split_stances,
		" split stances, maximum lift ", largest_lift, " at ", worst_lift, "; worst ", worst)
	if samples != 1728 or split_stances != samples or largest_lift > .011 \
			or float(worst.get("body", {}).get("gap", -INF)) < .0028 \
			or float(worst.get("weapon", {}).get("gap", -INF)) < .0028:
		quit(1)
		return
	quit()


func floor_box(center: float, top: float) -> void:
	var ground := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4., .2, 8.)
	collision.shape = shape
	ground.position = Vector3(center, top - .1, 0.0)
	ground.add_child(collision)
	root.add_child(ground)


func scan(body: int, x: float, heading: float) -> void:
	var actor := Registry.create(body)
	actor.position = Vector3(x, Height if x > 0.0 else 0.0, 0.0)
	actor.rotation.y = heading
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var rig: Skeleton3D = actor.skeleton
	var anchor := actor.global_transform
	var hand := rig.find_bone("bip01 r hand")
	var held := rig.find_bone("lizardman weapon")
	assert(hand >= 0 and held >= 0)
	var grip := rig.get_bone_rest(held)
	var skins := {}
	for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			skins[str(mesh.name)] = Ground.skin_points(mesh, rig)
	for clip: String in Clips:
		player.play(clip, 0.0)
		actor.current_clip = clip
		player.advance(0.0)
		for frame in 9:
			player.seek(player.current_animation_length * frame / 8.0, true)
			actor._physics_process(1.0 / 60.0)
			actor.contact._process_modification_with_delta(1.0 / 60.0)
			actor.contact.modification_processed.emit()
			rig.force_update_all_bone_transforms()
			assert(actor.global_transform == anchor)
			assert((rig.get_bone_global_pose(hand).inverse() * rig.get_bone_global_pose(held)).is_equal_approx(grip))
			if actor.living_lift > largest_lift:
				largest_lift = actor.living_lift
				var body_detail := {}
				worst_lift = {"body": body, "x": x, "heading": heading, "clip": clip, "phase": frame / 8.0,
					"body_gap": skin_gap(skins.values()[0], rig, body_detail), "body_detail": body_detail,
					"weapon_gap": skin_gap(skins.values()[1], rig),
					"stance": actor.contact.stance_gaps.duplicate()}
			if not actor.split_support.is_empty():
				split_stances += 1
			for label: String in skins:
				var gap := skin_gap(skins[label], rig)
				var key := "weapon" if label in ["Spear", "Mace"] else "body"
				if gap < float(worst.get(key, {}).get("gap", INF)):
					worst[key] = {"body": body, "x": x, "heading": heading, "clip": clip, "gap": gap,
						"phase": frame / 8.0, "split": not actor.split_support.is_empty(),
						"contacts": actor.contact.contacts.size(), "lift": actor.living_lift}
			samples += 1
	actor.queue_free()


func skin_gap(skin: Dictionary, rig: Skeleton3D, details: Dictionary = {}) -> float:
	var matrices: Array[Transform3D] = []
	for bind in skin.bones.size():
		matrices.append(rig.global_transform * rig.get_bone_global_pose(skin.bones[bind]) * skin.bind_poses[bind])
	var gap := INF
	for surface: Dictionary in skin.surfaces:
		for vertex in surface.points.size():
			var point := Vector3.ZERO
			var heaviest := 0.0
			var dominant := 0
			for slot in surface.stride:
				var index: int = vertex * surface.stride + slot
				var weight: float = surface.weights[index]
				if weight > 0.0:
					point += matrices[surface.bindings[index]] * surface.points[vertex] * weight
					if weight > heaviest:
						heaviest = weight
						dominant = skin.bones[surface.bindings[index]]
			var candidate := point.y - (Height if point.x > 0.0 else 0.0)
			if candidate < gap:
				gap = candidate
				details["point"] = str(point)
				details["joint"] = rig.get_bone_name(dominant)
	return gap
