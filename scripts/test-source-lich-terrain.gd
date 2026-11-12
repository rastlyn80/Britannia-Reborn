# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Step := .22
const Motions := ["Idle", "Walk", "Run", "Attack", "Cast", "Hit", "Fidget", "Pillage", "LieDown"]
const Optional := ["LichRaisedWard", "LichCoilingRise"]


func _initialize() -> void:
	create_timer(290.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	if enhanced:
		assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
	var candidate := "--lich-candidate" in OS.get_cmdline_user_args()
	if candidate:
		assert(preload("res://Presentation/SourceOccurrenceTerrainProfile.gd").enable().has(24))
	var lower := floor_box()
	var upper := floor_box()
	upper.position = Vector3(2, Step - .1, 0)
	var results := {}
	var checked := 0
	var penetrations := 0
	for support: String in ["flat", "slope", "step"]:
		var split := support == "step"
		var normal := Vector3(.17, 1.0, -.11).normalized() if support == "slope" else Vector3.UP
		var middle := Vector3(-2, 0, 0) if split else Vector3.ZERO
		lower.transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), middle - .1 * normal)
		(lower.get_child(0).shape as BoxShape3D).size.x = 4.0 if split else 8.0
		upper.collision_layer = 1 if split else 0
		await physics_frame
		await physics_frame
		for clip: String in (Motions + Optional if enhanced else Motions):
			var worst := {"gap": INF}
			var lift_change := 0.0
			for x: float in ([-.48, -.21, -.03, .15, .46] if split else [0.0]):
				for heading: float in [PI * .5, PI * 1.5]:
					var avatar := Avatar.new()
					avatar.initial_body = 24
					var anchor := Vector3(x, Step if split and x > 0.0 else 0.0, 0)
					avatar.position = anchor
					avatar.rotation.y = heading
					root.add_child(avatar)
					avatar.apply_server_appearance({"body": 24, "hue": 0x8035}, [])
					var actor: Node3D = avatar.horse_visual
					avatar.set_physics_process(false)
					actor.set_process(false)
					actor.set_physics_process(false)
					var rig: Skeleton3D = actor.skeleton
					var skins: Array[Dictionary] = []
					for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
						if mesh.skin != null and mesh.is_visible_in_tree():
							skins.append(Ground.skin_points(mesh, rig))
					assert(not skins.is_empty())
					var player: AnimationPlayer = actor.animator
					if not player.has_animation(clip):
						push_error("Missing body-24 clip " + clip)
						quit(1)
						return
					player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
					actor.current_clip = clip
					actor.action_remaining = 100.0
					for frame in 35:
						avatar._physics_process(1.0 / 60.0)
						avatar.animate(false, heading, 1.0 / 60.0, 0.0)
					actor._physics_process(1.0 / 60.0)
					player.play(clip, 0.0)
					player.advance(0.0)
					var previous_y := INF
					for frame in 31:
						var phase := frame / 30.0
						player.seek(player.current_animation_length * phase, true)
						actor._physics_process(1.0 / 60.0)
						actor.contact._process_modification_with_delta(1.0 / 60.0)
						actor.contact.modification_processed.emit()
						rig.force_update_all_bone_transforms()
						var gap := INF
						for skin: Dictionary in skins:
							var clearance := step_gap(skin, rig) if split else Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, normal)
							gap = minf(gap, clearance)
						var body_gap := gap
						var held_gap := INF
						for staff_mesh: MeshInstance3D in actor.staff_meshes():
							held_gap = minf(held_gap, staff_gap(staff_mesh, split, normal))
						gap = minf(gap, held_gap)
						assert(avatar.position == anchor and actor.native_hue == 0x8035 and is_finite(gap))
						if gap < .002:
							penetrations += 1
						if gap < worst.gap:
							worst = {"gap": gap, "body": body_gap, "staff": held_gap, "x": x, "phase": phase, "heading": heading}
						var current_y: float = actor.model.global_position.y
						if is_finite(previous_y):
							lift_change = maxf(lift_change, absf(current_y - previous_y))
						previous_y = current_y
						checked += 1
					avatar.free()
			results[support + ":" + clip] = worst.merged({"maximum_lift_change": lift_change})
	var treatment := ("enhanced" if enhanced else "classic") + ("-candidate" if candidate else "")
	var file := FileAccess.open("user://lich-terrain-%s.json" % treatment, FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	file.close()
	print("LICH TERRAIN ", treatment, ": ", checked, " full-skin poses, ", penetrations, " below 2 mm")
	quit(0 if checked == ((Motions.size() + (Optional.size() if enhanced else 0)) * 434) and (not candidate or penetrations == 0) else 1)



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


func staff_gap(mesh: MeshInstance3D, split: bool, normal: Vector3) -> float:
	var minimum := INF
	for index in mesh.mesh.get_surface_count():
		for local: Vector3 in mesh.mesh.surface_get_arrays(index)[Mesh.ARRAY_VERTEX]:
			var point := mesh.to_global(local)
			var floor := point.y - (Step if point.x >= 0.0 else 0.0) if split else normal.dot(point)
			minimum = minf(minimum, floor)
	return minimum
