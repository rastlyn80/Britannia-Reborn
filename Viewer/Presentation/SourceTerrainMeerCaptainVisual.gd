# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/MeerCaptainFallVisual.gd"

class CaptainTerrain extends "res://Presentation/SourceCreatureTreadTerrain.gd":
	var weapon_parts: Array[MeshInstance3D] = []
	var weapon_points: Array[PackedVector3Array] = []
	var weapon_skins: Array[Dictionary] = []
	var weapon_rigs: Array[Skeleton3D] = []

	func attach_weapon(crossbow: Node3D) -> void:
		for part: MeshInstance3D in crossbow.find_children("*", "MeshInstance3D", true, false):
			var points := PackedVector3Array()
			var rig := part.get_node_or_null(part.skeleton) as Skeleton3D if part.skin != null else null
			var posed := {}
			if rig != null:
				posed = Ground.skin_points(part, rig)
			else:
				for surface in part.mesh.get_surface_count():
					points.append_array(part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX])
			part.set_meta("optional_corpse_visual_prop", true)
			part.set_meta("corpse_prop_keeps_material", true)
			weapon_parts.append(part)
			weapon_points.append(points)
			weapon_skins.append(posed)
			weapon_rigs.append(rig)

	func weapon_gap() -> float:
		var minimum := INF
		for index in weapon_parts.size():
			var part := weapon_parts[index]
			if not part.is_visible_in_tree():
				continue
			var rig := weapon_rigs[index]
			if rig != null:
				rig.force_update_all_bone_transforms()
				var weapon_skin := weapon_skins[index]
				if split:
					var body_skin := skin
					skin = weapon_skin
					minimum = minf(minimum, step_gap(rig))
					skin = body_skin
				else:
					minimum = minf(minimum, Ground.minimum_plane_gap(
						weapon_skin, rig, rig.global_transform, plane.position, plane.normal))
			elif split:
				minimum = minf(minimum, piece_step_gap(weapon_points[index], part.global_transform, plane))
			else:
				for vertex: Vector3 in weapon_points[index]:
					var delta: Vector3 = part.to_global(vertex) - plane.position
					minimum = minf(minimum, delta.dot(plane.normal))
		return minimum

	func settle_live(allowed_depth := 0.0) -> void:
		super.settle_live(allowed_depth)
		if plane.is_empty():
			return
		actor.update_crossbow()
		var lift := maxf(0.0, (.003 - allowed_depth - weapon_gap()) / (1.0 if split else float(plane.normal.y)))
		actor.model.global_position.y += lift
		live_lift += lift
		actor.update_crossbow()

	func settle(visual: Node3D) -> void:
		super.settle(visual)
		if plane.is_empty():
			return
		visual.update_crossbow()
		var lift := maxf(0.0, (.002 - weapon_gap()) / (1.0 if split else float(plane.normal.y)))
		var before: Vector3 = visual.model.position
		visual.model.global_position.y += lift
		shift += visual.model.position - before
		visual.update_crossbow()

	func snapshot_floor(visual: Node3D) -> float:
		var floor := super.snapshot_floor(visual)
		for index in weapon_parts.size():
			var part := weapon_parts[index]
			if not part.is_visible_in_tree():
				continue
			var rig := weapon_rigs[index]
			if rig != null:
				rig.force_update_all_bone_transforms()
				var space := visual.global_transform.affine_inverse() * rig.global_transform
				floor = minf(floor, Ground.minimum_plane_gap(weapon_skins[index], rig, space, Vector3.ZERO, Vector3.UP))
			else:
				for vertex: Vector3 in weapon_points[index]:
					floor = minf(floor, visual.to_local(part.to_global(vertex)).y)
		return floor


var terrain := CaptainTerrain.new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.2, 2.2))
	animator.mixer_applied.disconnect(fall.settle.bind(self))
	contact.modification_processed.disconnect(ground_gesture.support.bind(self))
	contact.modification_processed.connect(support_archive_gesture)
	animator.mixer_applied.connect(settle_pose)
	contact.modification_processed.connect(settle_pose)


func set_equipment(worn: Array) -> void:
	var had_crossbow := is_instance_valid(crossbow)
	super.set_equipment(worn)
	if not had_crossbow and is_instance_valid(crossbow):
		terrain.attach_weapon(crossbow)


func support_archive_gesture() -> void:
	if terrain.plane.is_empty():
		ground_gesture.support(self)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	ground_gesture.release(self)
	terrain.sample()
	super._physics_process(delta)
	settle_pose()


func settle_pose() -> void:
	if terrain.plane.is_empty():
		return
	if not dead:
		terrain.settle_live(.0005)
	elif animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
		terrain.settle(self)


func receive_action(request: Dictionary) -> bool:
	if not dead:
		terrain.release_live()
		ground_gesture.release(self)
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	return terrain.begin_collapse(source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
