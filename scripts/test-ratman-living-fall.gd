# SPDX-License-Identifier: GPL-3.0-or-later
extends "ratman-terrain-test-fixture.gd"

const Snapshots := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Tick := 1.0 / 60.0
var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()
var transfers := 0
var frames := 0
var rows := {}


func _initialize() -> void:
	create_timer(180.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	if enhanced:
		assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
	assert(load("res://Presentation/SourceRatmanArcherProfile.gd").enable())
	load("res://Presentation/SourceRatmanTerrainProfile.gd").enable()
	var bodies := [42, 44, 45, 142, 143]
	var lower := board(6.0)
	var upper := board(4.0)
	upper.position = Vector3(2, Height - .1, 0)
	for normal: Vector3 in [Vector3.UP, Vector3(.12, 1, -.14).normalized(), Vector3.ZERO]:
		var split := normal == Vector3.ZERO
		var up := Vector3.UP if split else normal
		var center := Vector3(-2, 0, 0) if split else Vector3.ZERO
		lower.transform = Transform3D(Basis(Quaternion(Vector3.UP, up)), center - .1 * up)
		(lower.get_child(0).shape as BoxShape3D).size.x = 4.0 if split else 6.0
		upper.collision_layer = 1 if split else 0
		await physics_frame
		await physics_frame
		for body: int in bodies:
			for x: float in ([-.17, .16] if split else [0.0]):
				for yaw: float in [PI * .5, PI * 1.5]:
					replay(body, x, yaw, normal, "Walk", .39)
					replay(body, x, yaw, normal, "Run", .68)
					replay(body, x, yaw, normal, "Death", .36)
					if enhanced and body in [42, 143]:
						replay(body, x, yaw, normal, "RatmanAxeSomersault" if body == 42 else "RatmanMageLowClawBrace", .55)
	for body: int in rows:
		print("RATMAN FALL ", body, " ", JSON.stringify(rows[body]))
	print("RATMAN FALL: ", transfers, " transfers, ", frames, " samples; Enhanced ", enhanced)
	quit(0 if transfers == (136 if enhanced else 120) and frames == transfers * 17 else 1)


func board(width: float) -> StaticBody3D:
	var ground := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, .2, 8)
	collision.shape = shape
	ground.add_child(collision)
	root.add_child(ground)
	return ground


func actor_at(body: int, x: float, yaw: float) -> Node3D:
	var actor := Registry.create(body)
	actor.position = Vector3(x, Height if x > 0.0 else 0.0, 0)
	actor.rotation.y = yaw
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	if body == 142:
		actor.set_equipment([{"id": 0x13b2, "layer": 2, "hue": 0x489}])
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func replay(body: int, x: float, yaw: float, normal: Vector3, clip: String, phase: float) -> void:
	var source := actor_at(body, x, yaw)
	source.current_clip = clip
	if clip == "Death":
		source._physics_process(Tick)
		assert(source.receive_action({"protocol": "classic", "action": 2}))
		assert(source.dead)
	else:
		source.animator.play(clip, 0.0)
	source.animator.advance(0.0)
	source.animator.seek(source.animator.current_animation_length * phase, true)
	if not source.dead:
		source._physics_process(Tick)
		source.contact._process_modification_with_delta(Tick)
		source.contact.modification_processed.emit()
	source.skeleton.force_update_all_bone_transforms()
	var fall := actor_at(body, x, yaw)
	fall.dead = true
	fall.contact.enabled = false
	fall.model.transform = source.model.transform
	fall.current_clip = "Death"
	var duration: float = fall.begin_death_from(source)
	assert(duration > 0 and fall.current_clip in ["Death", "Death2"])
	var details := {"clip": clip, "phase": phase, "x": x, "yaw": yaw, "normal": str(normal)}
	var row: Dictionary = rows.get(body, {})
	var first_jump := maximum_joint_delta(source.skeleton, fall.skeleton)
	assert(first_jump < .001, "Ratman death changed the displayed pose at entry: %s" % details)
	record_max(row, "first_jump", first_jump, details)
	var beginning: float = fall.animator.current_animation_position
	for index in 17:
		var time := lerpf(beginning, fall.animator.current_animation_length, index / 16.0)
		fall.animator.seek(time, true)
		fall.skeleton.force_update_all_bone_transforms()
		var gap := floor_gap(fall, normal)
		assert(is_finite(gap) and gap >= -.0005, "Ratman death penetrated the ground: %s" % details)
		record_max(row, "penetration", -gap, details.merged({"time": time}))
		if index == 16:
			assert(gap <= .003, "Ratman death endpoint floats above the ground: %s" % details)
			record_max(row, "final_gap", gap, details)
		frames += 1
	var snapshot := Snapshots.capture(fall, fall.corpse_snapshot_floor())
	assert(not snapshot.is_empty() and snapshot.body == body)
	var frozen := snapshot.scene.instantiate() as Node3D
	assert(frozen.get_meta("native_hue") == 0x8035 and frozen.get_meta("death_clip") == fall.current_clip)
	assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
	var expected_prop := ""
	match body:
		42:
			if enhanced:
				expected_prop = "EnhancedRatmanAxe"
		142:
			expected_prop = "RatmanBow"
		143:
			expected_prop = "RatmanCrook" if enhanced and clip == "RatmanMageLowClawBrace" else "RatmanSword"
	for prop in ["EnhancedRatmanAxe", "RatmanBow", "RatmanCrook", "RatmanSword"]:
		assert(frozen.has_node(prop) == (prop == expected_prop), "Unexpected frozen prop %s for body %s: %s" % [prop, body, details])
	var live_gap := floor_gap(fall, normal)
	var frozen_gap := static_floor_gap(frozen, snapshot.placement, normal)
	assert(absf(live_gap - frozen_gap) < .0005, "Ratman corpse changed placement during freezing: %s" % details)
	record_max(row, "freeze_displacement", absf(live_gap - frozen_gap), details)
	frozen.free()
	source.free()
	fall.free()
	rows[body] = row
	transfers += 1


func maximum_joint_delta(before: Skeleton3D, after: Skeleton3D) -> float:
	before.force_update_all_bone_transforms()
	after.force_update_all_bone_transforms()
	var maximum := 0.0
	for index in before.get_bone_count():
		var prior := before.to_global(before.get_bone_global_pose(index).origin)
		var current := after.to_global(after.get_bone_global_pose(index).origin)
		maximum = maxf(maximum, prior.distance_to(current))
	return maximum


func floor_gap(actor: Node3D, normal: Vector3) -> float:
	var rig: Skeleton3D = actor.skeleton
	var gap := INF
	for mesh: MeshInstance3D in actor.contact.surfaces:
		if mesh.is_visible_in_tree():
			var skin: Dictionary = actor.contact.surfaces[mesh]
			var surface_gap := step_gap(skin, rig) if normal == Vector3.ZERO else Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, normal)
			gap = minf(gap, surface_gap)
	if actor.native_body == 142:
		var bow_gap_value: float = bow_step_gap(actor.bow) if normal == Vector3.ZERO else actor.bow_gap(Vector3.ZERO, normal, actor.bow.global_transform)
		gap = minf(gap, bow_gap_value)
	return gap


func static_floor_gap(frozen: Node3D, placement: Transform3D, normal: Vector3) -> float:
	var gap := INF
	for mesh: MeshInstance3D in frozen.get_children():
		for index in mesh.mesh.get_surface_count():
			for vertex: Vector3 in mesh.mesh.surface_get_arrays(index)[Mesh.ARRAY_VERTEX]:
				var point: Vector3 = placement * mesh.transform * vertex
				var depth := point.y - (Height if point.x > 0.0 else 0.0) if normal == Vector3.ZERO else normal.dot(point)
				gap = minf(gap, depth)
	return gap


func record_max(row: Dictionary, key: String, value: float, details: Dictionary) -> void:
	if value > float(row.get(key, {}).get("value", -INF)):
		row[key] = details.merged({"value": value})
