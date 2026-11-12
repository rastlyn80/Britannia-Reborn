# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Terrain := preload("res://Presentation/SourceFlyingCreatureTerrain.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const BodyIds := [163]
const GroundMotions := ["Idle", "Walk", "Run", "Attack", "Attack2", "Attack3", "Hit", "Fidget", "Cast2", "Stomp"]
const Step := .22
const Tick := 1.0 / 60.0

var cases := {}
var samples := 0
var failures := 0


func _initialize() -> void:
	create_timer(320.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	var candidate := "--snow-candidate" in OS.get_cmdline_user_args()
	if enhanced:
		assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
	if candidate:
		var active: Array = load("res://Presentation/SourceOccurrenceTerrainProfile.gd").enable()
		if not active.has(163):
			printerr("The saved Snow Elemental rigs were not selected for body 163: ", active)
			quit(1)
			return
	var lower := box(Vector3(12, .2, 16))
	var upper := box(Vector3(12, .2, 16))
	upper.position = Vector3(6, Step - .1, 0)
	for kind: String in ["flat", "slope", "step"]:
		var split := kind == "step"
		var normal := Vector3(.16, 1.0, -.10).normalized() if kind == "slope" else Vector3.UP
		var center := Vector3(-6, 0, 0) if split else Vector3.ZERO
		lower.transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), center - .1 * normal)
		(lower.get_child(0).shape as BoxShape3D).size.x = 12.0 if split else 24.0
		upper.collision_layer = 1 if split else 0
		await physics_frame
		await physics_frame
		for body: int in BodyIds:
			var actor := Registry.create(body)
			root.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var terrain := Terrain.new()
			terrain.bind(actor, Vector2(1.10, 1.15))
			var clips := GroundMotions + Array(actor.entry.get("archive_grounded_gestures", []))
			for clip: String in clips:
				if not actor.animator.has_animation(clip):
					printerr("Missing requested source Snow Elemental clip ", clip, " on ", body)
					quit(1)
					return
				for x: float in ([-.37, -.04, .29] if split else [0.0]):
					for yaw: float in [PI * .5, PI * 1.5]:
						sample(actor, terrain, kind, clip, x, yaw)
			actor.free()
	var report := OS.get_environment("BR_SNOW_METRICS")
	if not report.is_empty():
		var output := FileAccess.open(report, FileAccess.WRITE)
		output.store_string(JSON.stringify({"samples": samples, "rows": cases}, "  "))
		output.close()
	print("SNOW ELEMENTAL TERRAIN: ", samples, " full-skin poses, ", cases.size(),
		" body/terrain/clip combinations, ", failures, " below clearance; Enhanced ", enhanced)
	quit(0 if not candidate or failures == 0 else 1)


func sample(actor: Node3D, terrain: RefCounted, kind: String, clip: String, x: float, yaw: float) -> void:
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var origin := Vector3(x, Step if kind == "step" and x >= 0.0 else 0.0, 0)
	actor.position = origin
	actor.rotation.y = yaw
	actor.current_clip = clip
	actor.contact.enabled = true
	player.play(clip, 0.0)
	player.advance(0.0)
	terrain.sample()
	assert(not terrain.plane.is_empty())
	var key := "%d:%s:%s" % [actor.native_body, kind, clip]
	var worst: Dictionary = cases.get(key, {"gap": INF, "largest_lift_step": 0.0})
	var last_y := INF
	for i in 31:
		var phase := i / 30.0
		player.seek(player.current_animation_length * phase, true)
		actor._physics_process(Tick)
		actor.contact._process_modification_with_delta(Tick)
		actor.contact.modification_processed.emit()
		rig.force_update_all_bone_transforms()
		var gap: float = step_gap(terrain.skin, rig) if kind == "step" else Ground.minimum_plane_gap(terrain.skin,
			rig, rig.global_transform, terrain.plane.position, terrain.plane.normal)
		assert(is_finite(gap) and actor.position == origin and actor.native_hue == 0x8035)
		var minimum := .002
		if gap < minimum:
			failures += 1
		if gap < float(worst.gap):
			worst.merge({"gap": gap, "x": x, "yaw": yaw, "phase": phase}, true)
		var y: float = actor.model.global_position.y
		if is_finite(last_y):
			var change := absf(y - last_y)
			if change > float(worst.largest_lift_step):
				worst.largest_lift_step = change
				worst.lift_phase = phase
				worst.lift_x = x
				worst.lift_yaw = yaw
		last_y = y
		samples += 1
	cases[key] = worst


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
					point += matrices[surface.bindings[slot]] * surface.points[vertex] * weight
			minimum = minf(minimum, point.y - (Step if point.x >= 0.0 else 0.0))
	return minimum


func box(size: Vector3) -> StaticBody3D:
	var board := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	board.add_child(collision)
	root.add_child(board)
	return board
