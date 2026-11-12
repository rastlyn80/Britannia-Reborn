# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Height := .22
const Motions := ["Idle", "Walk", "Run", "Eat", "Attack", "Attack2", "Hit", "Fidget", "Fidget2",
	"FelineRearSwipe", "FelineRoll", "FelineStretch", "FelineSniff"]
var enhanced := "--enhanced" in OS.get_cmdline_user_args()
var poses := 0
var worst_gap := INF
var maximum_lift := 0.0


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	if enhanced:
		assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
	assert(preload("res://Presentation/SourceCougarLivingTerrainProfile.gd").enable())
	var flat := board(Vector3(6.0, .2, 6.0))
	var step := board(Vector3(4.0, .2, 6.0))
	step.position = Vector3(2.0, Height - .1, 0.0)
	for normal: Vector3 in [Vector3.UP, Vector3(.18, 1.0, .10).normalized(),
			Vector3(-.13, 1.0, .15).normalized(), Vector3.ZERO]:
		var split := normal == Vector3.ZERO
		var up := Vector3.UP if split else normal
		var center := Vector3(-2., 0., 0.) if split else Vector3.ZERO
		flat.transform = Transform3D(Basis(Quaternion(Vector3.UP, up)), center - .1 * up)
		(flat.get_child(0).shape as BoxShape3D).size.x = 4.0 if split else 6.0
		step.collision_layer = 1 if split else 0
		await physics_frame
		await physics_frame
		for body: int in [63]:
			for heading: float in [0.0, PI / 2.0, PI, PI * 1.5]:
				for x: float in ([-.14, .14] if split else [0.0]):
					scan(body, x, heading, normal)
	assert(poses == (4420 if enhanced else 2600))
	print("COUGAR LIVING SUPPORT: ", poses, " full-skin poses; minimum gap ", worst_gap,
		" m; largest visual lift ", maximum_lift, " m")
	quit()


func board(size: Vector3) -> StaticBody3D:
	var tile := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	tile.add_child(collider)
	root.add_child(tile)
	return tile


func scan(body: int, x: float, heading: float, normal: Vector3) -> void:
	var split := normal == Vector3.ZERO
	var row := Registry.entry(body)
	var actor := Registry.create(body)
	assert(actor != null)
	actor.position = Vector3(x, Height if x > 0.0 else 0.0, 0.0)
	actor.rotation.y = heading
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	var rig: Skeleton3D = actor.skeleton
	var mesh: MeshInstance3D = actor.model.find_children("*", "MeshInstance3D", true, false)[0]
	var skin := Ground.skin_points(mesh, rig)
	var animator: AnimationPlayer = actor.animator
	animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var clips := Motions.duplicate()
	clips.append_array(row.get("archive_grounded_gestures", []))
	for clip: String in clips:
		if not animator.has_animation(clip):
			continue
		actor.current_clip = clip
		animator.play(clip, 0.0)
		animator.advance(0.0)
		for index in 13:
			var phase := index / 12.0
			animator.seek(animator.current_animation_length * phase, true)
			actor._physics_process(1.0 / 60.0)
			actor.contact._process_modification_with_delta(1.0 / 60.0)
			actor.contact.modification_processed.emit()
			rig.force_update_all_bone_transforms()
			var gap := step_gap(skin, rig) if split else Ground.minimum_plane_gap(
				skin, rig, rig.global_transform, Vector3.ZERO, normal)
			assert(is_finite(gap) and gap >= .0029 and actor.support_lift < .12,
				"Cougar %d %s phase %f heading %f: gap %f, lift %f" % [body, clip, phase, heading, gap, actor.support_lift])
			worst_gap = minf(worst_gap, gap)
			maximum_lift = maxf(maximum_lift, actor.support_lift)
			poses += 1
	actor.free()


func step_gap(skin: Dictionary, rig: Skeleton3D) -> float:
	var matrices: Array[Transform3D] = []
	for bind in skin.bones.size():
		matrices.append(rig.global_transform * rig.get_bone_global_pose(skin.bones[bind]) * skin.bind_poses[bind])
	var lowest := INF
	for surface: Dictionary in skin.surfaces:
		for vertex in surface.points.size():
			var point := Vector3.ZERO
			for slot in surface.stride:
				var index: int = vertex * surface.stride + slot
				var weight: float = surface.weights[index]
				if weight > 0.0:
					point += matrices[surface.bindings[index]] * surface.points[vertex] * weight
			lowest = minf(lowest, point.y - (Height if point.x > 0.0 else 0.0))
	return lowest
