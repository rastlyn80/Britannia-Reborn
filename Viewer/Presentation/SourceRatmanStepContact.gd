# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceTrollGround.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Fall := preload("res://Presentation/SourceGroundedCreatureFall.gd")
const FloorProbes := [Vector2(-.66, -.66), Vector2(-.66, 0), Vector2(-.66, .66),
	Vector2(0, -.66), Vector2(0, .66), Vector2(.66, -.66), Vector2(.66, 0), Vector2(.66, .66)]
const OuterProbes := [Vector3(0, 0, -1.42), Vector3(0, 0, 1.42),
	Vector3(-.58, 0, -1.13), Vector3(.58, 0, -1.13), Vector3(-.58, 0, 1.13), Vector3(.58, 0, 1.13)]
const Compass := [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]
const InterruptibleIdle := ["Fidget", "Fidget2", "RatmanSniff", "RatmanQuietGuard", "RatmanAxeCheck",
	"MageGuardLook", "RatmanMageCrookWatch"]
const KneeTurns := [-.14, .14, -.30, .30, -.52, .52, -.72, .72]
var visual: Node3D
var surfaces: Dictionary
var skin: Dictionary
var tail_skin: Dictionary
var leg_skins: Array[Dictionary] = []
var sole_skins: Array[Dictionary] = []
var arms: Array[Dictionary] = []
var props: Dictionary
var tail: Array[int] = []
var neck: Array[int] = []
var head_skin: Dictionary
var ground: Dictionary
var correction := 0.0
var support_query := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.DOWN, 1)
var displayed := preload("res://Presentation/SourceRenderedPose.gd").new()
var displayed_space := Transform3D.IDENTITY
var death := Fall.new()


static func attach(actor: Node3D) -> void:
	var replacement := new()
	var former: SkeletonModifier3D = actor.contact
	var body: MeshInstance3D = former.surface
	former.free()
	actor.contact = replacement
	actor.skeleton.add_child(replacement)
	replacement.setup(actor, body)


func setup(actor: Node3D, body: MeshInstance3D) -> void:
	visual = actor
	preload("res://Presentation/SourceCreatureGaitLoop.gd").close_gaits(actor.animator)
	include_toe_descendants = true
	align_skinned_soles = true
	iterations = 5
	configure(body, false)
	assert(feet.size() == 2)
	var visible_body := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	skin = Ground.skin_points(visible_body, actor.skeleton)
	surfaces[visible_body] = skin
	for prop: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		if prop != visible_body and prop.skin != null and prop.name in [&"EnhancedRatmanAxe", &"RatmanSword", &"RatmanCrook"]:
			var prop_skin := Ground.skin_points(prop, actor.skeleton)
			surfaces[prop] = prop_skin
			props[prop] = int(prop_skin.bones[prop_skin.surfaces[0].bindings[0]])
	for name: String in ["bip01 tail4", "bip01 tail3", "bip01 tail2", "bip01 tail1", "bip01 tail"]:
		tail.append(actor.skeleton.find_bone(name))
	for name: String in ["bip01 head", "bip01 neck", "bip01 spine2"]:
		neck.append(actor.skeleton.find_bone(name))
	assert(not tail.has(-1) and not neck.has(-1))
	tail_skin = weighted_vertices(tail)
	head_skin = weighted_vertices(descendant_joints(neck[1]))
	for foot: Dictionary in feet:
		leg_skins.append(weighted_vertices([foot.a, foot.b]))
		sole_skins.append(weighted_vertices(descendant_joints(foot.b)))
	for side: String in ["l", "r"]:
		var joints := {"a": bone(side + " upperarm"), "b": bone(side + " forearm"), "c": bone(side + " hand")}
		var arm_skin := weighted_vertices(descendant_joints(joints.b))
		arms.append({"joints": joints, "skin": arm_skin})
	support_appendages = clear_step_appendages
	actor.animator.mixer_applied.connect(release)
	actor.animator.mixer_applied.connect(settle_death)
	modification_processed.connect(settle)
	modification_processed.connect(remember_display)


func remember_display() -> void:
	if not visual.dead:
		var rig := get_skeleton()
		displayed.capture(rig)
		displayed_space = visual.global_transform.affine_inverse() * rig.global_transform


func prepare_death() -> void:
	var support := ground if not ground.is_empty() else death.floor_under(visual)
	death.split = use_local_planes or spans_treads(support)
	death.remember_floor(visual, support)
	death.skin = death.supported_skin(visual)


func resume_gait(moving: bool) -> void:
	if moving and visual.current_clip in InterruptibleIdle:
		visual.action_remaining = 0.0


func settle_death() -> void:
	if not death.plane.is_empty():
		death.settle(visual)


func sample(space: PhysicsDirectSpaceState3D, origin: Vector3) -> void:
	release()
	super.sample(space, origin)
	ground = {}
	plane = {}
	use_local_planes = false
	if not enabled:
		return
	ground = cast_floor(space, origin)
	if ground.is_empty() or ground.normal.y < .8:
		return
	for hit: Dictionary in contacts.values():
		if differs(hit):
			use_local_planes = true
			return
	for offset: Vector2 in FloorProbes:
		var hit := cast_floor(space, origin + Vector3(offset.x, 0.0, offset.y))
		if not hit.is_empty() and hit.normal.y > .8 and differs(hit):
			use_local_planes = true
			return
	# The snout, tail, and a carried weapon can extend beyond the feet.
	for offset: Vector3 in OuterProbes:
		var hit := cast_floor(space, origin + visual.global_basis * offset)
		if not hit.is_empty() and hit.normal.y > .8 and differs(hit):
			use_local_planes = true
			return
	plane = ground


func cast_floor(space: PhysicsDirectSpaceState3D, point: Vector3) -> Dictionary:
	support_query.from = point + Vector3.UP * .65
	support_query.to = point - Vector3.UP * .65
	return space.intersect_ray(support_query)


func differs(hit: Dictionary) -> bool:
	var normal: Vector3 = ground.normal
	return normal.dot(hit.normal) < .995 or absf(normal.dot(hit.position - ground.position)) > .018


func spans_treads(support: Dictionary) -> bool:
	var space := get_world_3d().direct_space_state
	var origin: Vector3 = visual.global_position
	var normal: Vector3 = support.normal
	for offset: Vector3 in OuterProbes:
		var hit := cast_floor(space, origin + visual.global_basis * offset)
		if not hit.is_empty() and hit.normal.y > .8:
			if normal.dot(hit.normal) < .995 or absf(normal.dot(hit.position - support.position)) > .018:
				return true
	return false


func release() -> void:
	if correction > 0.0:
		visual.model.global_position.y -= correction
		correction = 0.0


func settle() -> void:
	if visual.dead or not enabled or ground.is_empty():
		return
	release()
	var rig := get_skeleton()
	rig.force_update_all_bone_transforms()
	var active: Array[Dictionary] = []
	for mesh: MeshInstance3D in surfaces:
		if mesh.is_visible_in_tree():
			active.append(surfaces[mesh])
	if use_local_planes:
		correction = float(step_conflict(ground.position.y, support_query, active).get("lift", 0.0))
	else:
		var gap := INF
		for points in active:
			gap = minf(gap, Ground.minimum_plane_gap(points, rig, rig.global_transform, ground.position, ground.normal))
		correction = maxf(0.0, (SoleClearance - gap) / float(ground.normal.y))
	visual.model.global_position.y += correction


func clear_step_appendages() -> void:
	var skinned: Array[Dictionary] = [tail_skin]
	for attempt in 2:
		for joint in tail:
			var conflict := step_conflict(ground.position.y, support_query, skinned)
			if float(conflict.get("lift", 0.0)) <= .001:
				break
			rotate_toward_surface(joint, conflict.point, conflict.normal, conflict.lift)
	var head_parts: Array[Dictionary] = [head_skin]
	var moving: bool = visual.current_clip in ["Walk", "Run"]
	var neck_joints := neck.slice(0, 2) if moving else neck
	for attempt in 3:
		for joint in neck_joints:
			var conflict := step_conflict(ground.position.y, support_query, head_parts)
			if float(conflict.get("lift", 0.0)) <= .015:
				break
			rotate_toward_surface(joint, conflict.point, conflict.normal, conflict.lift)
	for index in feet.size():
		clear_knee(feet[index], [leg_skins[index]])
	var approach := hand_approach()
	for arm: Dictionary in arms:
		clear_hand(arm, approach)
	for index in feet.size():
		clear_swing_foot(feet[index], [sole_skins[index]])
	for prop: MeshInstance3D in props:
		if prop.is_visible_in_tree():
			clear_prop(props[prop], [surfaces[prop]], arms[1].joints)


func descendant_joints(first: int) -> Array[int]:
	var rig := get_skeleton()
	var result: Array[int] = []
	for joint in rig.get_bone_count():
		var parent := joint
		while parent >= 0:
			if parent == first:
				result.append(joint)
				break
			parent = rig.get_bone_parent(parent)
	return result


func tread_direction() -> Vector3:
	var space := get_world_3d().direct_space_state
	var center: Vector3 = ground.position
	var normal: Vector3 = ground.normal
	var direction := Vector3.ZERO
	for offset: Vector3 in Compass:
		var hit := cast_floor(space, center + offset * 1.42)
		if hit.is_empty() or hit.normal.y < .8:
			continue
		var rise: float = normal.dot(hit.position - center)
		if absf(rise) > .04:
			direction += offset * signf(rise)
	return direction.normalized()


func clear_hand(arm: Dictionary, approach: float) -> void:
	var parts: Array[Dictionary] = [arm.skin]
	if approach > 0.0 and visual.current_clip in ["Walk", "Run"]:
		var rig := get_skeleton()
		var hand := rig.to_global(rig.get_bone_global_pose(arm.joints.c).origin)
		var target := hand.y + maxf(0.0, visual.global_position.y + .53 - hand.y) * approach
		for attempt in 6:
			for joint: int in [arm.joints.b, arm.joints.a]:
				hand = rig.to_global(rig.get_bone_global_pose(arm.joints.c).origin)
				var lift := maxf(0.0, target - hand.y)
				if lift > .001:
					rotate_toward_surface(joint, hand, Vector3.UP, lift)
	for attempt in 3:
		for joint: int in [arm.joints.c, arm.joints.b, arm.joints.a]:
			var conflict := step_conflict(ground.position.y, support_query, parts)
			if float(conflict.get("lift", 0.0)) <= .006:
				return
			rotate_toward_surface(joint, conflict.point, conflict.normal, conflict.lift)


func hand_approach() -> float:
	var uphill := tread_direction()
	if uphill.is_zero_approx():
		return 0.0
	var space := get_world_3d().direct_space_state
	var center: Vector3 = ground.position
	var ahead := cast_floor(space, center + uphill * 1.42)
	var direction := uphill if not ahead.is_empty() and differs(ahead) else -uphill
	var outer := cast_floor(space, center + direction * 1.42)
	if outer.is_empty() or not differs(outer):
		return 0.0
	var near := 0.0
	var far := 1.42
	for attempt in 7:
		var distance := (near + far) * .5
		var hit := cast_floor(space, center + direction * distance)
		if not hit.is_empty() and differs(hit):
			far = distance
		else:
			near = distance
	return 1.0 - smoothstep(.64, 1.32, far)


func clear_prop(joint: int, parts: Array[Dictionary], arm: Dictionary) -> void:
	for attempt in 8:
		var conflict := step_conflict(ground.position.y, support_query, parts)
		if float(conflict.get("lift", 0.0)) <= .001:
			return
		rotate_toward_surface(joint, conflict.point, conflict.normal, conflict.lift)
	for attempt in 2:
		var lift := float(step_conflict(ground.position.y, support_query, parts).get("lift", 0.0))
		if lift <= .006:
			return
		lift_foot(arm, minf(lift, .11))


func clear_swing_foot(foot: Dictionary, parts: Array[Dictionary]) -> void:
	for attempt in 3:
		var conflict := step_conflict(ground.position.y, support_query, parts)
		var lift := float(conflict.get("lift", 0.0))
		if lift <= .006:
			return
		var rig := get_skeleton()
		var hip := rig.get_bone_global_pose(foot.a)
		var knee := rig.get_bone_global_pose(foot.b)
		var ankle := rig.get_bone_global_pose(foot.c)
		var point: Vector3 = conflict.point
		var space := get_world_3d().direct_space_state
		var best := Vector3.ZERO
		for offset: Vector2 in FloorProbes:
			var sideways := Vector3(offset.x, 0.0, offset.y) * .095
			var hit := cast_floor(space, Vector3(point.x, ground.position.y, point.z) + sideways)
			if hit.is_empty() or hit.position.y > point.y + .012:
				continue
			var target := ankle.origin + rig.global_basis.inverse() * sideways
			set_knee(foot, hip, knee, ankle, knee.origin)
			move_ankle(foot, hip.origin, knee.origin, ankle, target)
			var needed := float(step_conflict(ground.position.y, support_query, parts).get("lift", 0.0))
			if needed < lift - .012:
				best = sideways
				lift = needed
			if lift <= .006:
				break
		set_knee(foot, hip, knee, ankle, knee.origin)
		var offset := best + Vector3.UP * minf(lift, .24)
		move_ankle(foot, hip.origin, knee.origin, ankle, ankle.origin + rig.global_basis.inverse() * offset)


func move_ankle(foot: Dictionary, hip: Vector3, knee: Vector3, ankle: Transform3D, target: Vector3) -> void:
	var rig := get_skeleton()
	aim(foot.a, foot.b, FootContact.knee_target(hip, knee, ankle.origin, target))
	aim(foot.b, foot.c, target)
	ankle.origin = rig.get_bone_global_pose(foot.c).origin
	rig.set_bone_global_pose(foot.c, ankle)


func clear_knee(foot: Dictionary, parts: Array[Dictionary]) -> void:
	var remaining := float(step_conflict(ground.position.y, support_query, parts).get("lift", 0.0))
	if remaining < .018:
		return
	var rig := get_skeleton()
	var hip := rig.get_bone_global_pose(foot.a)
	var knee := rig.get_bone_global_pose(foot.b)
	var ankle := rig.get_bone_global_pose(foot.c)
	var axis := (ankle.origin - hip.origin).normalized()
	var leg := knee.origin - hip.origin
	if leg.cross(axis).length_squared() < .000001:
		return
	var best := 0.0
	for angle: float in KneeTurns:
		set_knee(foot, hip, knee, ankle, hip.origin + leg.rotated(axis, angle))
		var needed := float(step_conflict(ground.position.y, support_query, parts).get("lift", 0.0))
		if needed < remaining - .001:
			remaining = needed
			best = angle
		if remaining <= .006:
			break
	set_knee(foot, hip, knee, ankle, hip.origin + leg.rotated(axis, best))


func set_knee(foot: Dictionary, hip: Transform3D, knee: Transform3D, ankle: Transform3D, target: Vector3) -> void:
	var rig := get_skeleton()
	rig.set_bone_global_pose(foot.a, hip)
	rig.set_bone_global_pose(foot.b, knee)
	rig.set_bone_global_pose(foot.c, ankle)
	aim(foot.a, foot.b, target)
	aim(foot.b, foot.c, ankle.origin)
	rig.set_bone_global_pose(foot.c, ankle)


func weighted_vertices(joints: Array[int]) -> Dictionary:
	var result: Array[Dictionary] = []
	for source: Dictionary in skin.surfaces:
		var points := PackedVector3Array()
		var bindings := PackedInt32Array()
		var weights := PackedFloat32Array()
		var stride: int = source.stride
		for vertex: int in source.points.size():
			var start: int = vertex * stride
			var score := 0.0
			for influence: int in stride:
				var index: int = start + influence
				if int(skin.bones[source.bindings[index]]) in joints:
					score += source.weights[index]
			if score < .5:
				continue
			points.append(source.points[vertex])
			for influence in stride:
				bindings.append(source.bindings[start + influence])
				weights.append(source.weights[start + influence])
		result.append({"points": points, "bindings": bindings, "weights": weights, "stride": stride})
	return {"bones": skin.bones, "bind_poses": skin.bind_poses, "surfaces": result}
