# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Hooves := preload("res://Presentation/SourceTrollGround.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const SplitFall := preload("res://Presentation/CougarTerrainFall.gd")
const Probes := [Vector3(-.50, 0, -.76), Vector3(.50, 0, -.76),
	Vector3(-.50, 0, .76), Vector3(.50, 0, .76)]
var actor: Node3D
var skins: Array[Dictionary] = []
var floor := {}
var split := false
var lift := 0.0
var ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.DOWN, 1)
var fall := SplitFall.new()
var transferring := false
var starting := false


func bind(visual: Node3D) -> void:
	actor = visual
	var mesh: MeshInstance3D = actor.contact.surface
	actor.contact.free()
	actor.contact = Hooves.new()
	actor.skeleton.add_child(actor.contact)
	actor.contact.include_toe_descendants = true
	actor.contact.configure(mesh, true)
	assert(actor.contact.feet.size() == 4)
	skins.append(Ground.skin_points(mesh, actor.skeleton))
	fall.skin = skins[0]
	actor.animator.mixer_applied.connect(release)
	actor.contact.modification_processed.connect(settle)


func sample(delta: float) -> void:
	if actor.dead or not actor.contact.enabled:
		return
	release()
	var space := actor.get_world_3d().direct_space_state
	actor.contact.sample(space, actor.global_position)
	floor = hit_under(actor.global_position)
	split = false
	actor.contact.plane = {}
	actor.contact.use_local_planes = false
	if floor.is_empty():
		return
	for hit: Dictionary in actor.contact.contacts.values():
		if different(hit):
			split = true
			break
	if not split:
		for offset: Vector3 in Probes:
			var hit := hit_under(actor.to_global(offset))
			if not hit.is_empty() and different(hit):
				split = true
				break
	actor.contact.use_local_planes = split
	if not split:
		actor.contact.plane = floor
	var normal: Vector3 = floor.normal
	if split and actor.contact.contacts.size() == 4:
		var points: Dictionary = actor.contact.contacts
		var along: Vector3 = points[1].position + points[3].position - points[0].position - points[2].position
		var across: Vector3 = points[2].position + points[3].position - points[0].position - points[1].position
		var lean := along.cross(across).normalized()
		lean = -lean if lean.y < 0.0 else lean
		if lean.y > .8:
			var angle := normal.angle_to(lean)
			if angle > .001:
				normal = normal.slerp(lean, minf(1.0, .18 / angle))
	var up: Vector3 = (actor.global_basis.inverse() * normal).normalized()
	var target: Basis = Basis(Quaternion(Vector3.UP, up)) * actor.source_model_basis.orthonormalized()
	var model: Node3D = actor.model
	model.basis = model.basis.orthonormalized().slerp(target, 1.0 - exp(-14.0 * delta)).scaled_local(model.scale)
	actor.contact.sample(space, actor.global_position)


func hit_under(point: Vector3) -> Dictionary:
	ray.from = point + Vector3.UP * .65
	ray.to = point - Vector3.UP * .65
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit if not hit.is_empty() and hit.normal.y > .75 else {}


func different(hit: Dictionary) -> bool:
	var normal: Vector3 = floor.normal
	return normal.dot(hit.normal) < .995 or absf(normal.dot(hit.position - floor.position)) > .02


func release() -> void:
	if actor.dead:
		return
	actor.model.global_position.y -= lift
	lift = 0.0


func settle() -> void:
	if actor.dead or floor.is_empty():
		return
	release()
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	if split:
		lift = float(actor.contact.step_conflict(floor.position.y, ray, skins).get("lift", 0.0))
	else:
		var normal: Vector3 = floor.normal
		var gap := Ground.minimum_plane_gap(skins[0], rig, rig.global_transform, floor.position, normal)
		lift = maxf(0.0, (.003 - gap) / normal.y)
	actor.model.global_position.y += lift
	actor.rendered_pose.capture(rig)


func begin_fall(source: Node3D, clip: String) -> float:
	floor = source.ground.floor.duplicate()
	split = source.ground.split
	transferring = true
	starting = true
	actor.global_transform = source.global_transform
	actor.model.transform = source.model.transform
	actor.current_clip = clip
	actor.dead = true
	actor.recovering_tip = false
	actor.contact.enabled = false
	fall.split = split
	fall.remember_floor(actor, floor if not floor.is_empty() else fall.floor_under(source))
	var time: float = source.animator.current_animation_position if source.dead else 0.0
	var speed: float = absf(source.animator.get_playing_speed()) if source.dead else 1.0
	if is_zero_approx(speed):
		speed = 1.0
	var length: float = actor.animator.get_animation(clip).length
	fall.blend_start = time
	fall.blend_length = minf(.12 * speed, length - time)
	var source_space: Transform3D = source.skeleton.global_transform
	if fall.blend_length > 0.0:
		var rig: Skeleton3D = source.skeleton
		var displayed: Skeleton3D = rig if source.dead else source.rendered_pose.source(rig)
		for joint in displayed.get_bone_count():
			fall.blend_pose.append(displayed.get_bone_pose(joint))
		if displayed != rig:
			displayed.free()
	actor.animator.speed_scale = 1.0
	actor.animator.play(clip, 0.0, speed)
	actor.animator.advance(0.0)
	actor.animator.seek(time, true)
	if not fall.blend_pose.is_empty():
		var rig: Skeleton3D = actor.skeleton
		var root_adjustment := rig.global_transform.affine_inverse() * source_space
		for joint in rig.get_bone_count():
			if rig.get_bone_parent(joint) < 0:
				fall.blend_pose[joint] = root_adjustment * fall.blend_pose[joint]
	starting = false
	fall.settle(actor)
	actor.action_remaining = maxf(0.0, length - time) / speed
	return actor.action_remaining


func settle_transferred_fall() -> void:
	if not starting:
		fall.settle(actor)


func settle_fall(prior_shift: Vector3) -> Vector3:
	if not split or not actor.dead or floor.is_empty() or actor.animator.current_animation_length <= 0.0:
		return prior_shift
	var model: Node3D = actor.model
	model.position -= prior_shift
	fall.plane = floor
	var gap := fall.step_gap(actor.skeleton)
	var shift := .002 - gap
	if shift < 0.0:
		var phase: float = actor.animator.current_animation_position / actor.animator.current_animation_length
		shift *= smoothstep(.75, 1.0, phase)
	var before := model.position
	if is_finite(shift):
		model.global_position.y += shift
	return model.position - before
