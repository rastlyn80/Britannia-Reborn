# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceTrollGround.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const TerrainFall := preload("res://Presentation/SourceGroundedCreatureFall.gd")
const Legs := [[4, 5, 6], [8, 9, 10], [12, 13, 14], [16, 17, 18],
	[20, 21, 22], [24, 25, 26], [28, 29, 30], [32, 33, 34]]
const Probes := [Vector3(-1.6, 0, -1.6), Vector3(-1.6, 0, 1.6),
	Vector3(1.6, 0, -1.6), Vector3(1.6, 0, 1.6), Vector3.FORWARD * 2.0, Vector3.BACK * 2.0]
const Approach := [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
var spider: Node3D
var skin: Dictionary
var surfaces: Dictionary
var ground: Dictionary
var lift := 0.0
var approach_lift := 0.0
var displayed := preload("res://Presentation/SourceRenderedPose.gd").new()
var displayed_space := Transform3D.IDENTITY
var death := TerrainFall.new()


func setup(actor: Node3D, mesh: MeshInstance3D) -> void:
	spider = actor
	surface = mesh
	arrays = mesh.mesh.surface_get_arrays(0)
	skin = Ground.skin_points(mesh, get_skeleton())
	surfaces[mesh] = skin
	var rig := get_skeleton()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bindings: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	assert(mesh.mesh.get_surface_count() == 1 and bindings.size() == vertices.size() * 4)
	for chain: Array in Legs:
		var joints := chain.map(func(index: int) -> int: return rig.find_bone("bone%02d" % index))
		assert(not joints.has(-1))
		var tips: Array[int] = []
		var seen := {}
		for vertex in vertices.size():
			if seen.has(vertices[vertex]):
				continue
			var weight := 0.0
			for index in range(vertex * 4, vertex * 4 + 4):
				if skin.bones[bindings[index]] == joints[2]:
					weight += weights[index]
			if weight >= .5:
				tips.append(vertex)
				seen[vertices[vertex]] = true
		assert(not tips.is_empty())
		feet.append({"a": joints[0], "b": joints[1], "c": joints[2], "end": joints[2], "vertices": tips})
	modification_processed.connect(settle)
	modification_processed.connect(remember_display)
	spider.animator.mixer_applied.connect(release)
	spider.animator.mixer_applied.connect(settle_death)


func sample(space: PhysicsDirectSpaceState3D, origin: Vector3) -> void:
	release()
	plane = {}
	ground = {}
	use_local_planes = false
	approach_lift = 0.0
	if not enabled:
		return
	plane = floor_at(space, origin, origin.y)
	if plane.is_empty():
		return
	ground = plane
	use_local_planes = spans_treads(plane)
	# Sample stance candidates after tilting to the continuous surface.
	var local_normal: Vector3 = (spider.global_basis.inverse() * plane.normal).normalized()
	var tilt := Basis(Quaternion(Vector3.UP, local_normal))
	spider.model.basis = (tilt * spider.source_model_basis).scaled_local(spider.model.scale)
	super.sample(space, origin)
	for hit: Dictionary in contacts.values():
		if separate_tread(hit):
			use_local_planes = true
			break
	if use_local_planes:
		approach_lift = approaching_riser(space, origin)


func floor_at(space: PhysicsDirectSpaceState3D, point: Vector3, y: float) -> Dictionary:
	floor_query.from = Vector3(point.x, y + .65, point.z)
	floor_query.to = Vector3(point.x, y - .65, point.z)
	var hit := space.intersect_ray(floor_query)
	return hit if not hit.is_empty() and hit.normal.y >= .8 else {}


func separate_tread(hit: Dictionary) -> bool:
	return not hit.is_empty() and (plane.normal.dot(hit.normal) < .995
		or absf(plane.normal.dot(hit.position - plane.position)) > .018)


func spans_treads(support: Dictionary) -> bool:
	var space := get_world_3d().direct_space_state
	var origin: Vector3 = spider.global_position
	var normal: Vector3 = support.normal
	for offset: Vector3 in Probes:
		var hit := floor_at(space, origin + spider.global_basis * offset, origin.y)
		if not hit.is_empty() and (normal.dot(hit.normal) < .995
				or absf(normal.dot(hit.position - support.position)) > .018):
			return true
	return false


func approaching_riser(space: PhysicsDirectSpaceState3D, origin: Vector3) -> float:
	var height: float = plane.position.y
	var target := height
	for direction: Vector3 in Approach:
		var outer := floor_at(space, origin + direction * 1.65, origin.y)
		if not separate_tread(outer) or outer.position.y <= height + .04:
			continue
		var lower := 0.0
		var upper := 1.65
		for attempt in 7:
			var distance := (lower + upper) * .5
			var hit := floor_at(space, origin + direction * distance, origin.y)
			if separate_tread(hit) and hit.position.y > height + .04:
				upper = distance
			else:
				lower = distance
		var blend := 1.0 - smoothstep(.64, 1.65, upper)
		target = maxf(target, lerpf(height, outer.position.y, blend))
	return maxf(0.0, target - origin.y)


func _process_modification_with_delta(delta: float) -> void:
	release()
	if enabled and not spider.dead:
		lift = approach_lift
		spider.model.global_position.y += lift
	super._process_modification_with_delta(delta)
	if enabled and not spider.dead and approach_lift > .015:
		reach_lower_tread()


func reach_lower_tread() -> void:
	for index in feet.size():
		var hit: Dictionary = contacts.get(index, {})
		if hit.is_empty():
			continue
		var foot: Dictionary = feet[index]
		var sole := sample_sole(foot, hit)
		if sole.is_empty() or float(sole.gap) <= .004:
			continue
		# Use the authored foot's height before the belly clears the riser.
		# Low feet may reach down, while the source swing stays lifted.
		var weight := 1.0 - smoothstep(.04, .18, maxf(0.0, float(sole.gap) - approach_lift))
		var target := float(sole.gap) - minf(approach_lift, float(sole.gap) - .004) * weight
		for attempt in 4:
			for joint: int in [foot.b, foot.a]:
				if sole.is_empty() or float(sole.gap) <= target + .002:
					break
				rotate_toward_surface(joint, sole.point, sole.normal, target - float(sole.gap))
				sole = sample_sole(foot, hit)


func remember_display() -> void:
	if not spider.dead:
		var rig := get_skeleton()
		displayed.capture(rig)
		displayed_space = spider.global_transform.affine_inverse() * rig.global_transform


func prepare_death() -> void:
	var support := ground if not ground.is_empty() else death.floor_under(spider)
	death.split = use_local_planes or spans_treads(support)
	death.remember_floor(spider, support)


func settle_death() -> void:
	if not death.plane.is_empty():
		death.settle(spider)


func release() -> void:
	if lift > 0.0:
		spider.model.global_position.y -= lift
		lift = 0.0


func settle() -> void:
	if spider.dead or not enabled or plane.is_empty():
		return
	var rig := get_skeleton()
	rig.force_update_all_bone_transforms()
	var remainder := 0.0
	if use_local_planes:
		remainder = float(step_conflict(plane.position.y, floor_query, [skin]).get("lift", 0.0))
	else:
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.position, plane.normal)
		remainder = maxf(0.0, (SoleClearance - gap) / float(plane.normal.y))
	spider.model.global_position.y += remainder
	lift += remainder
