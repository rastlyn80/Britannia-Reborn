# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Height := .22
const Tick := 1.0 / 60.0
const ClipSpeeds := {"Walk": 1.7, "Run": 4.5}
const TerminalJoints := ["bone10", "bone14", "bone18", "bone22",
	"bone26", "bone30", "bone34", "bone06"]

var rows := {}
var samples := 0
var lower: StaticBody3D
var upper: StaticBody3D


func _initialize() -> void:
	create_timer(180.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	lower = floor_board(4.0, -2.0, 0.0)
	upper = floor_board(4.0, 2.0, Height)
	var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
	if enhanced:
		assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
	var candidate := "--baseline" not in OS.get_cmdline_user_args()
	if candidate:
		assert(load("res://Presentation/SourceGiantSpiderTerrainProfile.gd").enable())
	for treatment: String in Registry.entry(28).assets:
		var actor := Registry.create(28)
		actor.treatment = treatment
		root.add_child(actor)
		actor.apply_identity(28, 0x8035)
		actor.set_process(false)
		actor.set_physics_process(false)
		var player: AnimationPlayer = actor.animator
		var rig: Skeleton3D = actor.skeleton
		var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh, rig)
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		assert(TerminalJoints.all(func(label: String) -> bool: return rig.find_bone(label) >= 0))
		var row := {"rig_joints": rig.get_bone_count(), "skin_points": skin.unique_vertices, "contact_chains": actor.contact.feet.size()}
		for board: String in ["flat", "slope", "step"]:
			var tilted := board == "slope"
			var split := board == "step"
			var normal := Vector3(.13, 1.0, -.10).normalized() if tilted else Vector3.UP
			var center := Vector3(-2, 0, 0) if split else Vector3.ZERO
			lower.transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), center - .1 * normal)
			(lower.get_child(0).shape as BoxShape3D).size.x = 4.0 if split else 8.0
			upper.collision_layer = 1 if split else 0
			await physics_frame
			await physics_frame
			var board_row := {}
			for clip: String in ClipSpeeds:
				for direction: float in [1.0, -1.0]:
					for phase: float in [0.0, .34, .68]:
						cross(actor, skin, clip, direction, phase, normal, split, board_row)
			if candidate:
				var seam_limit := .17 if split else .065
				assert(board_row.loop_seam.value < seam_limit and board_row.model_lift_step.value < .06,
					"Spider gait discontinuity: %s %s" % [treatment, board])
			row[board] = board_row
		rows[treatment] = row
		actor.free()
	var profile := "enhanced" if enhanced else "classic"
	for treatment: String in rows:
		print("GIANT SPIDER ", treatment, " ", JSON.stringify(rows[treatment]))
	print("GIANT SPIDER TERRAIN: ", samples, " samples, ", profile)
	quit(0 if samples == 6750 else 1)


func floor_board(width: float, x: float, height: float) -> StaticBody3D:
	var board := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, .2, 8.0)
	collider.shape = shape
	board.add_child(collider)
	board.position = Vector3(x, height - .1, 0)
	root.add_child(board)
	return board


func cross(actor: Node3D, skin: Dictionary, clip: String, direction: float,
		start: float, normal: Vector3, split: bool, row: Dictionary) -> void:
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	var speed: float = ClipSpeeds[clip]
	var span := 2.5
	var frames := int(ceil(span / (speed * Tick)))
	var prior := PackedVector3Array()
	var prior_phase := 0.0
	var prior_lift := 0.0
	actor.rotation.y = direction * PI * .5
	actor.current_clip = clip
	player.play(clip, 0.0)
	player.advance(0.0)
	for frame in frames + 1:
		var x := direction * span * (frame / float(frames) - .5)
		var y := Height * clampf(x + .5, 0.0, 1.0) if split else -normal.x * x / normal.y
		var anchor := Vector3(x, y, 0)
		actor.position = anchor
		var phase := fposmod(start + frame * Tick / player.current_animation_length, 1.0)
		player.seek(phase * player.current_animation_length, true)
		actor._physics_process(Tick)
		actor.contact._process_modification_with_delta(Tick)
		actor.contact.modification_processed.emit()
		rig.force_update_all_bone_transforms()
		assert(actor.position == anchor and actor.native_hue == 0x8035)
		var info := {"clip": clip, "x": x, "phase": phase, "start": start, "direction": direction}
		var detail := {}
		var gap := minimum_gap(skin, rig, normal, split, detail)
		assert(is_finite(gap))
		maximum(row, "nearest_vertex_clearance", gap, info.merged(detail))
		if "--baseline" not in OS.get_cmdline_user_args():
			assert(gap > .001, "Spider crossed the terrain: %s" % info)
			var lift: float = actor.contact.lift
			maximum(row, "model_lift", lift, info.merged(detail))
			if frame > 0:
				maximum(row, "model_lift_step", absf(lift - prior_lift), info)
			prior_lift = lift
		maximum(row, "penetration", -gap, info)
		var tips := PackedVector3Array()
		for label: String in TerminalJoints:
			var point := rig.to_global(rig.get_bone_global_pose(rig.find_bone(label)).origin) - anchor
			if not prior.is_empty():
				var distance := prior[tips.size()].distance_to(point)
				var joint := info.merged({"joint": label})
				maximum(row, "largest_joint_step", distance, joint)
				if phase < prior_phase:
					maximum(row, "loop_seam", distance, joint)
			tips.append(point)
		prior = tips
		prior_phase = phase
		samples += 1


func minimum_gap(skin: Dictionary, rig: Skeleton3D, normal: Vector3, split: bool, detail: Dictionary = {}) -> float:
	if not split:
		return Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, normal)
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
			var gap := point.y - (Height if point.x >= 0.0 else 0.0)
			if gap < minimum:
				minimum = gap
				var joints := {}
				for influence in surface.stride:
					var slot: int = vertex * surface.stride + influence
					if float(surface.weights[slot]) > 0.0:
						joints[rig.get_bone_name(skin.bones[surface.bindings[slot]])] = surface.weights[slot]
				detail["vertex_joints"] = joints
				detail["vertex_world"] = str(point)
				detail["vertex_rest"] = str(surface.points[vertex])
				detail["core_world"] = str(rig.to_global(rig.get_bone_global_pose(rig.find_bone("bone01")).origin))
	return minimum


func maximum(row: Dictionary, label: String, value: float, info: Dictionary) -> void:
	if value > float(row.get(label, {}).get("value", -INF)):
		row[label] = info.merged({"value": value})
