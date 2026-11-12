# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceTrollGround.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Fall := preload("res://Presentation/SourceGroundedCreatureFall.gd")
const Gaits := preload("res://Presentation/SourceCreatureGaitLoop.gd")
const Probes := [Vector3(-.66, 0, -.92), Vector3(.66, 0, -.92),
	Vector3(-.66, 0, .92), Vector3(.66, 0, .92), Vector3.FORWARD * 1.18, Vector3.BACK * 1.18]
const AssemblyProbes := [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]
const IdleGestures := ["Fidget", "Fidget2", "BoneStretch", "SkeletonSkullCheck", "SkeletonLooseGuard"]
const Assembly := "SkeletonAssemble"
const AssemblyJoin := .60 # Visibility switches at the authored join in bake-skeleton-enhanced.gd.

var visual: Node3D
var surfaces: Dictionary
var ground: Dictionary
var lift := 0.0
var displayed := preload("res://Presentation/SourceRenderedPose.gd").new()
var displayed_space := Transform3D.IDENTITY
var death := Fall.new()
var pieces: Node3D
var piece_vertices: Dictionary
var shifted_pieces: Dictionary
var assembly_rise := 0.0


static func attach(actor: Node3D, detached_bones: Node3D = null) -> void:
	var support := new()
	var mesh: MeshInstance3D = actor.contact.surface
	actor.contact.free()
	actor.contact = support
	actor.skeleton.add_child(support)
	support.bind(actor, mesh, detached_bones)


func bind(actor: Node3D, mesh: MeshInstance3D, detached_bones: Node3D) -> void:
	visual = actor
	pieces = detached_bones
	include_toe_descendants = true
	align_skinned_soles = true
	var quadruped: bool = actor.entry.get("limb_support", "") == "quadruped"
	configure(mesh, quadruped)
	assert(feet.size() == (4 if quadruped else 2))
	for part: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		if part.skin != null and part.name != &"SourceContactReference":
			surfaces[part] = Ground.skin_points(part, get_skeleton())
	if pieces != null:
		for piece: MeshInstance3D in pieces.get_children():
			piece_vertices[piece] = piece.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	Gaits.close_gaits(actor.animator)
	actor.animator.mixer_applied.connect(release)
	actor.animator.mixer_applied.connect(settle_death)
	modification_processed.connect(settle)
	modification_processed.connect(remember_display)


func sample(space: PhysicsDirectSpaceState3D, origin: Vector3) -> void:
	release()
	ground = hit_at(space, origin, origin.y)
	plane = {}
	use_local_planes = false
	if ground.is_empty() or not enabled:
		return
	var local_up: Vector3 = (visual.global_basis.inverse() * ground.normal).normalized()
	var tilt := Basis(Quaternion(Vector3.UP, local_up))
	visual.model.basis = (tilt * visual.source_model_basis).scaled_local(visual.model.scale)
	super.sample(space, origin)
	use_local_planes = spans_treads(ground)
	for hit: Dictionary in contacts.values():
		if separate_tread(ground, hit):
			use_local_planes = true
			break
	if not use_local_planes:
		plane = ground
	assembly_rise = 0.0
	if use_local_planes and visual.current_clip == Assembly:
		for direction: Vector3 in AssemblyProbes:
			var hit := hit_at(space, origin + direction * .75, origin.y)
			if separate_tread(ground, hit):
				assembly_rise = maxf(assembly_rise, float(hit.position.y) - origin.y)


func hit_at(space: PhysicsDirectSpaceState3D, point: Vector3, y: float) -> Dictionary:
	floor_query.from = Vector3(point.x, y + .65, point.z)
	floor_query.to = Vector3(point.x, y - .65, point.z)
	var hit := space.intersect_ray(floor_query)
	return hit if not hit.is_empty() and hit.normal.y > .8 else {}


func separate_tread(support: Dictionary, hit: Dictionary) -> bool:
	return not hit.is_empty() and (support.normal.dot(hit.normal) < .995
		or absf(support.normal.dot(hit.position - support.position)) > .018)


func spans_treads(support: Dictionary) -> bool:
	var space := get_world_3d().direct_space_state
	var origin: Vector3 = visual.global_position
	for offset: Vector3 in Probes:
		if separate_tread(support, hit_at(space, origin + visual.global_basis * offset, origin.y)):
			return true
	return false


func release() -> void:
	if lift > 0.0:
		visual.model.global_position.y -= lift
		lift = 0.0
	for piece: MeshInstance3D in shifted_pieces:
		var motion: Array = shifted_pieces[piece]
		# Animation may already have supplied a fresh transform in this frame.
		if piece.transform.is_equal_approx(motion[1]):
			piece.transform = motion[0]
	shifted_pieces.clear()


func _process_modification_with_delta(delta: float) -> void:
	# The loose pieces join the exact authored skeleton pose. Deforming the
	# hidden feet would make them jump away from their matching pieces.
	if visual.current_clip != Assembly:
		super._process_modification_with_delta(delta)


func settle() -> void:
	var gathering: bool = visual.dead and visual.has_method("finishing_assembly") and visual.finishing_assembly()
	if (visual.dead and not gathering) or ground.is_empty():
		return
	release()
	if pieces != null and pieces.visible:
		support_assembly()
	elif enabled or gathering:
		lift = body_lift(false)
		if visual.current_clip == Assembly:
			lift = maxf(lift, assembly_step_lift(assembly_phase()))
		visual.model.global_position.y += lift


func body_lift(include_hidden: bool) -> float:
	var active: Array[Dictionary] = []
	for part: MeshInstance3D in surfaces:
		if include_hidden or part.is_visible_in_tree():
			active.append(surfaces[part])
	var rig := get_skeleton()
	rig.force_update_all_bone_transforms()
	if use_local_planes:
		return float(step_conflict(ground.position.y, floor_query, active).get("lift", 0.0))
	var gap := INF
	for skin: Dictionary in active:
		gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, ground.position, ground.normal))
	return maxf(0.0, (SoleClearance - gap) / float(ground.normal.y))


func support_assembly() -> void:
	var phase := assembly_phase()
	var together := smoothstep(.40, AssemblyJoin, phase)
	var needed := {}
	var highest := 0.0
	for piece: MeshInstance3D in piece_vertices:
		if not piece.is_visible_in_tree():
			continue
		var gap := piece_gap(piece)
		if not is_finite(gap):
			continue
		var rise := SoleClearance - gap
		if rise < 0.0:
			# Scattered bones can rest on the lower tread before they lift.
			rise = clampf(.014 - gap, -.24, 0.0) * (1.0 - smoothstep(.20, .42, phase))
		needed[piece] = rise
		highest = maxf(highest, rise)
	if together > 0.0:
		lift = maxf(maxf(highest, body_lift(true)) * together, assembly_step_lift(phase))
		visual.model.global_position.y += lift
	for piece: MeshInstance3D in needed:
		var rise: float = needed[piece]
		var offset := maxf(0.0, rise - lift) if rise > 0.0 else rise
		if not is_zero_approx(offset):
			var before := piece.transform
			piece.global_position.y += offset
			shifted_pieces[piece] = [before, piece.transform]


func assembly_phase() -> float:
	var player: AnimationPlayer = visual.animator
	return player.current_animation_position / maxf(.001, player.current_animation_length)


func assembly_step_lift(phase: float) -> float:
	# Hold the high tread through the join, then let the standing motion
	# settle as its feet move clear of the ledge.
	return assembly_rise * smoothstep(.40, AssemblyJoin, phase) * (1.0 - smoothstep(.81, 1.0, phase))


func piece_gap(piece: MeshInstance3D) -> float:
	var space := get_world_3d().direct_space_state
	var normal: Vector3 = ground.normal
	var height: float = ground.position.y
	var nearest := INF
	var transform := piece.global_transform
	for vertex: Vector3 in piece_vertices[piece]:
		var point := transform * vertex
		if use_local_planes:
			if point.y > height + .65:
				continue
			var hit := hit_at(space, point, height)
			if not hit.is_empty():
				nearest = minf(nearest, point.y - float(hit.position.y))
		else:
			var distance := normal.dot(point - ground.position) / normal.y
			nearest = minf(nearest, distance)
	return nearest


func remember_display() -> void:
	if not visual.dead:
		var rig := get_skeleton()
		displayed.capture(rig)
		displayed_space = visual.global_transform.affine_inverse() * rig.global_transform


func resume_gait(moving: bool) -> void:
	if moving and visual.current_clip in IdleGestures:
		visual.action_remaining = 0.0


func prepare_death() -> void:
	var support := ground if not ground.is_empty() else death.floor_under(visual)
	death.split = use_local_planes or spans_treads(support)
	death.remember_floor(visual, support)
	death.skin = death.supported_skin(visual)


func settle_death() -> void:
	if not death.plane.is_empty():
		death.settle(visual)
