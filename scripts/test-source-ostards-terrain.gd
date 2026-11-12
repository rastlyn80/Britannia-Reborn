# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Ostard := preload("res://Presentation/SourceEnhancedOstard.gd")
const Mounts := preload("res://Presentation/MountVisual.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")
const Samples := 33
var selectors := 0
var poses := 0
var handoffs := 0
var pose_error := 0.0
var kick_lift := 0.0
var terminal_hip := 0.0
var body: int


func _initialize() -> void:
	create_timer(70.0).timeout.connect(func(): quit(2))
	run.call_deferred()


func run() -> void:
	var folder: String = get_script().resource_path.get_base_dir()
	var audit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("source-ostard-sequences.json")))
	for form: int in Ostard.Forms:
		body = form
		await test_form(audit[str(body)].modes)
	assert(kick_lift > .25 and handoffs == 54 and pose_error < .003)
	print("SOURCE OSTARDS CANDIDATE: ", selectors, " official mode selections, ", poses, " weighted poses, ",
		handoffs, " fall transfers, max joint jump ", pose_error, " m, kick clearance ", kick_lift,
		" m, maximum resting pelvis height ", terminal_hip, " m")
	quit()


func test_form(modes: Array) -> void:
	Ostard.configure(false)
	var classic := Mounts.create(body)
	assert(not classic is Ostard and classic.kind == Ostard.Forms[body].kind)
	classic.free()
	Ostard.configure(true)
	var item: int = Ostard.Forms[body].item
	assert(Ostard.active.has(body) and Mounts.mount_available(body, item))
	check_selectors(modes)
	for style: String in Ostard.Treatments:
		var actor := spawn(style)
		var other := 219 if body == 210 else 210
		assert(not Mounts.matches(actor, other) and not Mounts.matches(actor, body, Ostard.Forms[other].item))
		var clips: Array = Ostard.Groups.values()
		for gaits: Array in Ostard.Gaits:
			for clip: String in gaits:
				if not clips.has(clip):
					clips.append(clip)
		assert(clips.size() == 18)
		for clip: String in clips:
			sample_flat(actor, clip)
		var first := endpoint(actor, "Death")
		var second := endpoint(actor, "Death2")
		assert(first.distance_to(second) > .20)
		actor.set_native_combat_flags(0)
		actor.play_gait(false, 0.0)
		assert(actor.current_clip == "OstardPeaceIdle")
		actor.set_native_combat_flags(64)
		actor.play_gait(false, 0.0)
		assert(actor.current_clip == "OstardCombatReady" and not actor.has_meta("native_action"))
		actor.action_remaining = 0.0
		actor.play_gait(true, 2.0)
		assert(actor.current_clip == "Walk")
		actor.apply_identity(body, 0x8035, item)
		actor.play_gait(true, 5.5)
		assert(actor.current_clip == "OstardSeatedRun" and actor.reins.visible)
		actor.free()
		if body == 210 and Ostard.DesertActions.available():
			check_classic_desert(style)

	var board := StaticBody3D.new()
	root.add_child(board)
	var surface := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10., .10, 10.)
	surface.shape = shape
	board.add_child(surface)
	for normal: Vector3 in [Vector3.UP, Vector3(.21, 1., .19).normalized(), Vector3(-.23, 1., -.27).normalized()]:
		board.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), -.05 * normal)
		await physics_frame
		await physics_frame
		for angle: float in [0.0, .73, -1.62]:
			for selection: int in [-1, 0, 1]:
				check_handoff(board, angle, selection)
	board.free()


func check_classic_desert(style: String) -> void:
	for group: int in [4, 6, 8, 9, 10, 11, 12]:
		var actor := spawn(style)
		assert(actor.desert_actions != null)
		assert(actor.receive_action({"protocol": "classic", "body": body, "action": group}))
		var expected: String = actor.DesertActions.CLIPS.get(group, "Death")
		assert(actor.current_clip == expected)
		if group in [8, 12]:
			assert(actor.using_classic_fall and actor.animator.get_animation(expected) == actor.classic_falls[expected])
		actor.animator.advance(.12)
		actor.animator.seek(actor.animator.current_animation_length * .42, true)
		if group == 12:
			var corpse := spawn(style)
			corpse.global_transform = actor.global_transform
			corpse.model.transform = actor.model.transform
			assert(corpse.begin_source_death(actor) > 0.0)
			assert(corpse.current_clip == expected and corpse.using_classic_fall)
			corpse.free()
		actor.free()


func check_selectors(modes: Array) -> void:
	for mode in modes.size():
		var sources: Array = modes[mode].new_protocol_actions
		for type in 18:
			for subaction: int in [-1, 0, 1, 2, 3, 9]:
				var groups := reference_groups(sources, type, subaction)
				if groups.is_empty() and int(modes[mode].fallback_mode) >= 0:
					groups = reference_groups(modes[int(modes[mode].fallback_mode)].new_protocol_actions, type, subaction)
				for variation in 128:
					var expected := -1 if groups.is_empty() else int(groups[variation % groups.size()])
					assert(Ostard.action_group(mode, type, subaction, variation) == expected)
					selectors += 1


func reference_groups(sources: Array, type: int, subaction: int) -> Array:
	var groups: Array = []
	for entry: Dictionary in sources:
		if int(entry.type) != type:
			continue
		if int(entry.subaction) == subaction:
			return entry.groups
		if int(entry.subaction) == -1:
			groups = entry.groups
	return groups


func spawn(style := "modern") -> Ostard:
	var actor := Mounts.create(body) as Ostard
	actor.treatment = style
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func start(actor: Ostard, clip: String) -> void:
	actor.animator.stop()
	actor.skeleton.reset_bone_poses()
	actor.animator.play(clip, 0.)
	actor.animator.advance(0.)


func sample_flat(actor: Ostard, clip: String) -> void:
	start(actor, clip)
	var length := actor.animator.current_animation_length
	for sample in Samples:
		actor.animator.seek(length * float(sample) / (Samples - 1), true)
		actor.skeleton.force_update_all_bone_transforms()
		var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var bounds := Geometry.deformed_bounds(mesh, actor.skeleton)
		assert(bounds.is_finite() and bounds.get_longest_axis_size() > .80, clip + str(bounds))
		if clip in Ostard.Groups.values():
			var gap := Ground.minimum_plane_gap(actor.fall.skin, actor.skeleton, actor.skeleton.global_transform,
				Vector3.ZERO, Vector3.UP)
			assert(gap >= -.004, clip + " penetrates level floor by " + str(gap))
			if clip == "OstardLeapingKick":
				kick_lift = maxf(kick_lift, gap)
		if clip in ["Death", "Death2"] and sample == Samples - 1:
			var rig := actor.skeleton
			var hip := rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 pelvis")).origin).y
			assert(hip < .40, "the corpse is balanced on a limb at height %.3f m" % hip)
			terminal_hip = maxf(terminal_hip, hip)
		poses += 1


func endpoint(actor: Ostard, clip: String) -> Vector3:
	start(actor, clip)
	actor.animator.seek(actor.animator.current_animation_length, true)
	var rig := actor.skeleton
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 head")).origin)


func check_handoff(board: StaticBody3D, angle: float, selection: int) -> void:
	var source := spawn()
	source.rotation.y = angle
	var packet := {"protocol": "new", "body": body, "type": 3, "subaction": 0, "variation": maxi(0, selection)}
	if selection < 0:
		packet.type = 5
		packet.variation = 1
	assert(source.receive_enhanced_action(packet, 64))
	source.animator.advance(0.12)
	source.animator.seek(source.animator.current_animation_length * .57, true)
	var target := spawn()
	target.global_transform = source.global_transform
	target.model.transform = source.model.transform
	assert(target.begin_source_death(source) > 0.0)
	assert(target.current_clip == ("Death2" if selection == 1 else "Death"))
	var plane := target.fall.plane
	assert(plane.get("collider") == board)
	for joint in source.skeleton.get_bone_count():
		var first := source.skeleton.to_global(source.skeleton.get_bone_global_pose(joint).origin)
		var second := target.skeleton.to_global(target.skeleton.get_bone_global_pose(joint).origin)
		pose_error = maxf(pose_error, first.distance_to(second))
	var start_time := target.animator.current_animation_position
	var end := target.animator.current_animation_length
	for sample in Samples:
		target.animator.seek(lerpf(start_time, end, float(sample) / (Samples - 1)), true)
		var gap := Ground.minimum_plane_gap(target.fall.skin, target.skeleton, target.skeleton.global_transform,
			plane.position, plane.normal)
		assert(gap >= .0016 and (sample < Samples - 1 or gap < .0024))
		poses += 1
	var snapshot := Snapshot.capture(target, target.corpse_snapshot_floor())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == 0x8035
		and corpse.get_meta("death_clip") == target.current_clip and corpse.find_children("*", "Skeleton3D").is_empty())
	corpse.free()
	source.free()
	target.free()
	handoffs += 1
