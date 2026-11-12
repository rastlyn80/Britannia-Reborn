# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Height := .22
const Clips := ["Idle", "Walk", "Run", "Fidget", "KneelingSwing", "Hit"]
var samples := 0
var split_stances := 0
var worst := {}
var largest_lift := 0.0
var worst_lift := {}


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	var enhanced := "--enhanced" in OS.get_cmdline_user_args()
	if enhanced:
		assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
	assert(preload("res://Presentation/SourceTrollLivingTerrainProfile.gd").enable())
	floor_box(-2.0, 0.0)
	floor_box(2.0, Height)
	await physics_frame
	await physics_frame
	for body: int in [53, 54, 55]:
		for x: float in [-.36, -.14, .14, .36]:
			for heading: float in [0.0, PI * .5, PI, PI * 1.5]:
				scan(body, x, heading, enhanced)
	print("TROLL LIVING STEPS: ", samples, " poses, ", split_stances,
		" split stances, maximum lift ", largest_lift, " at ", worst_lift, "; worst ", worst)
	assert(samples == (4752 if enhanced else 2592))
	assert(split_stances == samples and largest_lift < .040)
	assert(worst.body.gap >= .0029 and worst.weapon.gap >= .0029)
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


func scan(body: int, x: float, heading: float, enhanced: bool) -> void:
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
	var skins := {}
	for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			skins[str(mesh.name)] = {"node": mesh, "skin": Ground.skin_points(mesh, rig)}
	var clips := Clips.duplicate()
	if enhanced:
		clips.append_array(actor.entry.get("archive_grounded_gestures", []))
	for clip: String in clips:
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
			if actor.living_lift > largest_lift:
				largest_lift = actor.living_lift
				var body_detail := {}
				worst_lift = {"body": body, "x": x, "heading": heading, "clip": clip, "phase": frame / 8.0,
					"body_gap": skin_gap(skins["Body"].skin, rig, body_detail), "body_detail": body_detail,
					"weapon_visible": actor.prop != null and actor.prop.visible,
					"stance": actor.contact.stance_gaps.duplicate()}
			if not actor.split_support.is_empty():
				split_stances += 1
			for label: String in skins:
				if not skins[label].node.is_visible_in_tree():
					continue
				var gap := skin_gap(skins[label].skin, rig)
				var key := "body" if label == "Body" else "weapon"
				if gap < float(worst.get(key, {}).get("gap", INF)):
					worst[key] = {"body": body, "x": x, "heading": heading, "clip": clip, "gap": gap,
						"phase": frame / 8.0, "split": not actor.split_support.is_empty(),
						"contacts": actor.contact.contacts.size(), "lift": actor.living_lift}
			samples += 1
	actor.free()


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
