# SPDX-License-Identifier: GPL-3.0-or-later
extends "ratman-terrain-test-fixture.gd"

const Tick := 1.0 / 60.0
const HalfWidth := 1.05
var frames := 0
var enhanced := "--enhanced-creature-actions" in OS.get_cmdline_user_args()

func _initialize() -> void:
	create_timer(180.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	if enhanced:
		assert(preload("res://Presentation/EnhancedCreatureProfile.gd").enable())
	assert(load("res://Presentation/SourceRatmanArcherProfile.gd").enable())
	load("res://Presentation/SourceRatmanTerrainProfile.gd").enable()
	floor_box(-2, 0)
	floor_box(2, Height)
	await physics_frame
	await physics_frame
	var bodies := [42, 44, 45, 142, 143]
	for body: int in bodies:
		var actor := Registry.create(body)
		root.add_child(actor)
		actor.apply_identity(body, 0x8035)
		if body == 142:
			actor.set_equipment([{"id": 0x13b2, "layer": 2, "hue": 0x489}])
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var row := {}
		for speed: float in [1.7, 4.5]:
			for direction: float in [1.0, -1.0]:
				for phase: float in [0.0, .34, .68]:
					cross(actor, speed, direction, phase, row)
		assert(row.penetration.value < -.001 and row.loop_seam.value < .11 and row.lift.value < .065)
		print("RATMAN CROSSING ", body, " ", JSON.stringify(row))
		actor.free()
	print("RATMAN CROSSING: ", frames, " samples; Enhanced ", enhanced)
	quit(0 if frames == 3180 else 1)


func cross(actor: Node3D, speed: float, direction: float, start: float, row: Dictionary) -> void:
	var clip := "Run" if speed > 3 else "Walk"
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	actor.rotation.y = direction * PI * .5
	actor.current_clip = clip
	player.play(clip, 0)
	player.advance(0)
	var duration := player.current_animation_length
	var count := int(ceil(2.0 * HalfWidth / (speed * Tick)))
	var prior := 0.0
	var prior_phase := 0.0
	var previous: Array[Vector3] = []
	for index in count + 1:
		var x := direction * lerpf(-HalfWidth, HalfWidth, index / float(count))
		# Match the visual interpolation between server tile centers straddling the riser.
		var anchor := Vector3(x, Height * clampf(x + .5, 0.0, 1.0), 0)
		actor.position = anchor
		var phase := fposmod(start + index * Tick * (speed / (1.7 if clip == "Walk" else 4.5)) / duration, 1.0)
		player.seek(duration * phase, true)
		actor._physics_process(Tick)
		actor.contact._process_modification_with_delta(Tick)
		actor.contact.modification_processed.emit()
		rig.force_update_all_bone_transforms()
		assert(actor.position == anchor)
		var current: float = actor.contact.correction
		var pose: Array[Vector3] = []
		var stride_jump := 0.0
		var joints := ["bip01 l foot", "bip01 r foot", "cp_grasp_lhand", "cp_grasp_rhand", "bip01 tail4", "bip01 head"]
		var moving_joint := ""
		var differences := {}
		for joint: String in joints:
			var point := rig.to_global(rig.get_bone_global_pose(rig.find_bone(joint)).origin) - anchor
			if index > 0 and point.distance_to(previous[pose.size()]) > stride_jump:
				stride_jump = point.distance_to(previous[pose.size()])
				moving_joint = joint
			if index > 0:
				differences[joint] = point.distance_to(previous[pose.size()])
			pose.append(point)
		var details := {"x": x, "direction": direction, "clip": clip, "phase": phase, "start": start}
		record_max(row, "lift", current, details)
		if index > 0:
			record_max(row, "lift_change", absf(prior - current), details)
			record_max(row, "joint_change", stride_jump, details.merged({"joint": moving_joint}))
			if phase < prior_phase:
				record_max(row, "loop_seam", stride_jump, details.merged({"joints": differences}))
		prior = current
		prior_phase = phase
		previous = pose
		for mesh: MeshInstance3D in actor.contact.surfaces:
			if mesh.is_visible_in_tree():
				var gap := step_gap(actor.contact.surfaces[mesh], rig)
				record_max(row, "penetration", -gap, details.merged({"mesh": str(mesh.name)}))
		if actor.native_body == 142:
			record_max(row, "penetration", -bow_step_gap(actor.bow), details.merged({"mesh": "RatmanBow"}))
		frames += 1


func record_max(row: Dictionary, key: String, value: float, details: Dictionary) -> void:
	if value > float(row.get(key, {}).get("value", -INF)):
		row[key] = details.merged({"value": value})
