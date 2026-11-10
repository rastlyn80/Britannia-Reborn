# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/lich-gaman/"
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Families := {24: "Lich", 248: "Gaman"}
const Modes := {
	24: {"0": {"8": ["LichRaisedWard"], "15": ["LichCoilingRise"]}, "1": {}},
	248: {"0": {"2": ["GamanHornRecoil", "GamanHornRecoil"],
		"5": ["GamanLowWatch", "GamanShortShove"], "8": ["GamanHeadAlert"],
		"11": ["GamanShoulderLunge", "GamanShoulderLunge", "GamanShoulderLunge"],
		"14": ["GamanNoseDip"], "15": ["GamanRearAndSettle"]}, "1": {"5": ["GamanLowWatch"]}},
}


func run() -> void:
	var installed := "--installed" in OS.get_cmdline_user_args()
	var bases := {}
	for body: int in Families:
		bases[body] = Registry.entry(body)
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var evidence := {}
	for body: int in Families:
		var row := Registry.entry(body) if installed else candidate_row(body, bases[body])
		assert(row.enhanced_source_action_groups == Modes[body])
		Registry.entries[body] = row
		evidence[str(body)] = await review(game, body, bases[body], row, installed)
		assert(not evidence[str(body)].is_empty())
		Registry.entries[body] = bases[body]
	game.free()
	if not installed:
		var output := FileAccess.open(Stage + "terrain-receipt.json", FileAccess.WRITE)
		assert(output != null)
		output.store_string(JSON.stringify({"bodies": evidence, "script_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		output.close()
	quit()

func candidate_row(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = Modes[body]
	row.archive_grounded_gestures = motion_packets(body).keys()
	row.assets = {}
	for treatment: String in Installed.registered_assets(base):
		row.assets[treatment] = Stage + "%d-%s.scn" % [body, treatment]
	return row

func motion_packets(body: int) -> Dictionary:
	var clips := {}
	for kind: String in Modes[body]["0"]:
		var names: Array = Modes[body]["0"][kind]
		for variant in names.size():
			if not clips.has(names[variant]):
				clips[names[variant]] = [int(kind), variant]
	return clips

func review(game: Node, body: int, base: Dictionary, row: Dictionary, installed: bool) -> Dictionary:
	game.entities[body] = {"body": body, "serial": body, "hue": 0x8035}
	var clips := motion_packets(body)
	var result := {"decoded": 0, "classic": 0, "poses": 0, "terrain": {}, "hashes": {},
		"falls": 0, "maximum_death_jump": 0.0, "hues": 0, "interruptions": 0}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := create_fit(body, treatment, installed)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				verify_retained(actor, base)
				var counts := check_routes(avatar, game, body, Modes[body])
				result.decoded += counts.x
				result.classic += counts.y
				result.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				if body == 24:
					result.interruptions = check_lich_interruptions(actor, avatar, game)
			for clip: String in clips:
				var selection: Array = clips[clip]
				var request := decode(game, body, selection[0], selection[1])
				var measurements := review_clip(actor, avatar, floor, request, clip)
				assert(not measurements.is_empty())
				result.poses += 31
				if tilt == Vector3.ZERO and treatment == "modern":
					result.terrain[clip] = measurements
				for phase: float in [.10, .58]:
					var fall := review_fall(actor, avatar, floor, request, phase, installed)
					assert(fall.has("jump"))
					result.falls += 1
					result.maximum_death_jump = maxf(result.maximum_death_jump, fall.jump)
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	assert(result.decoded == (144 if body == 248 else 48) and result.classic == (108 if body == 248 else 36)
		and result.falls == clips.size() * 10 * row.assets.size())
	for hue: int in [0, 0x8035, 0x455]:
		var corpse := Corpses.build(body, hue)
		assert(corpse != null and corpse.get_meta("graphic_id") == 0x2006 and corpse.get_meta("corpse_body") == body)
		assert(corpse.get_meta("native_hue") == hue and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
		result.hues += 1
	print("LICH AND GAMAN ", body, ": ", result)
	return result

func verify_retained(actor: Node3D, base: Dictionary) -> void:
	var body: int = actor.native_body
	var active := Registry.entry(body)
	Registry.entries[body] = base
	var reference := Registry.create(body)
	Registry.entries[body] = active
	reference.treatment = actor.treatment
	root.add_child(reference)
	reference.apply_identity(body, actor.native_hue)
	for name: String in reference.animator.get_animation_list():
		assert(actor.animator.has_animation(name), name)
		var before: Animation = reference.animator.get_animation(name)
		var after: Animation = actor.animator.get_animation(name)
		assert(before.length == after.length and before.get_track_count() == after.get_track_count(), name)
		for track in before.get_track_count():
			assert(before.track_get_path(track) == after.track_get_path(track), name)
			assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track),
				"%d/%s %s %s" % [body, actor.treatment, name, before.track_get_path(track)])
	reference.free()

func create_fit(body: int, treatment: String, installed: bool) -> Node3D:
	var renderer := Stage + "SourceEnhanced%sVisual.gd" % Families[body]
	var actor: Node3D = Registry.create(body) if installed else load(renderer).new()
	actor.entry = Registry.entry(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor

func start_fit(actor: Node3D, avatar: Avatar, request: Dictionary) -> void:
	actor.animator.stop()
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	actor.animator.advance(.19)
	assert(Dispatch.dispatch(avatar, request, true, 0x40))
	actor.animator.advance(.14)

func move_to(actor: Node3D, phase: float) -> void:
	actor.animator.seek(actor.animator.current_animation_length * phase, true)
	actor._physics_process(1.0 / 60.0)
	actor.contact.modification_processed.emit()
	actor.skeleton.force_update_all_bone_transforms()

static func bone(actor: Node3D, label: String) -> Vector3:
	var rig: Skeleton3D = actor.skeleton
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(label)).origin)

func check_lich_interruptions(actor: Node3D, avatar: Avatar, game: Node) -> int:
	var rig: Skeleton3D = actor.skeleton
	var root_bone := rig.find_bone("__root")
	for route: String in ["alert", "classic", "walk"]:
		start_fit(actor, avatar, decode(game, 24, 15, 0))
		actor.animator.seek(actor.animator.current_animation_length * .12, true)
		assert(rig.get_bone_pose_scale(root_bone).y < .35)
		actor.animator.seek(actor.animator.current_animation_length * .28, true)
		assert(actor.rise_ribbon.visible)
		match route:
			"alert":
				assert(Dispatch.dispatch(avatar, decode(game, 24, 8, 0), true, 64))
			"classic":
				assert(Classic.dispatch(avatar, {"protocol": "classic", "body": 24, "serial": 24,
					"action": 4, "frames": 5, "repeat_count": 1, "delay": 0}))
			_:
				actor.action_remaining = 0.0
				actor.play_gait(true, 1.5)
		for step in 21:
			actor.animator.advance(1.0 / 60.0)
		assert(rig.get_bone_pose_scale(root_bone).is_equal_approx(Vector3.ONE), route)
		assert(not actor.rise_ribbon.visible, route)
	return 3

func review_clip(actor: Node3D, avatar: Avatar, floor: StaticBody3D, request: Dictionary, clip: String) -> Dictionary:
	start_fit(actor, avatar, request)
	assert(actor.current_clip == clip)
	var lich: bool = actor.native_body == 24
	var skin: Dictionary = actor.gesture_ground.skin if lich else actor.control_skin
	var rendered_mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var rendered := Ground.skin_points(rendered_mesh, actor.skeleton)
	var lowest := INF
	var highest := -INF
	var gap := INF
	var render_gap := INF
	var staff_floor := INF
	for i in 31:
		move_to(actor, i / 30.0)
		gap = minf(gap, Ground.minimum_plane_gap(skin, actor.skeleton, actor.skeleton.global_transform,
			floor.position, floor.basis.y))
		render_gap = minf(render_gap, Ground.minimum_plane_gap(rendered, actor.skeleton, actor.skeleton.global_transform,
			floor.position, floor.basis.y))
		var motion := bone(actor, "bip01 head").y
		if clip == "LichRaisedWard":
			motion = bone(actor, "bip01 l hand").y
		elif clip == "GamanShoulderLunge":
			motion = bone(actor, "bip01 r hand").z
		if lich and actor.staff != null:
			var pole_gap: float = actor.staff_gap(actor.staff.global_transform, floor.basis.y)
			pole_gap += (actor.model.global_position - floor.position).dot(floor.basis.y)
			staff_floor = minf(staff_floor, pole_gap)
		lowest = minf(lowest, motion)
		highest = maxf(highest, motion)
	assert(gap >= .0019, "%s slope %s gap %f" % [clip, floor.rotation, gap])
	assert(render_gap >= 0.0, "%s rendered skin crosses the slope by %f m" % [clip, render_gap])
	var required: float = {"LichCoilingRise": 1.7, "LichRaisedWard": .50, "GamanRearAndSettle": .55,
		"GamanShoulderLunge": .20}.get(clip, 0.0)
	assert(highest - lowest >= required, "%s lost its distinct motion: %.5f" % [clip, highest - lowest])
	assert(staff_floor >= -.001, "%s held staff crosses %s by %f m" % [clip, floor.rotation, staff_floor])
	return {"gap": gap, "render_gap": render_gap, "minimum": lowest, "maximum": highest,
		"staff_floor": staff_floor if is_finite(staff_floor) else null}

func review_fall(actor: Node3D, avatar: Avatar, floor: StaticBody3D, request: Dictionary,
		phase: float, installed: bool) -> Dictionary:
	start_fit(actor, avatar, request)
	move_to(actor, phase)
	var labels := ["bip01 head", "bip01 l hand", "bip01 r foot"]
	var prior: Array[Vector3] = []
	for label: String in labels:
		prior.append(bone(actor, label))
	var held_staff: bool = actor.native_body == 24 and actor.staff != null
	var held_transform: Transform3D = actor.staff.global_transform if held_staff else Transform3D.IDENTITY
	var fall := create_fit(actor.native_body, actor.treatment, installed)
	fall.global_transform = actor.global_transform
	fall.model.transform = actor.model.transform
	fall.dead = true
	fall.contact.enabled = false
	var duration: float = fall.begin_death_from(actor)
	if actor.native_body == 24:
		assert(not fall.rise_ribbon.visible)
	var jump := 0.0
	if held_staff:
		for point: Vector3 in [Vector3.ZERO, Vector3.UP, Vector3.RIGHT]:
			jump = maxf(jump, (held_transform * point).distance_to(fall.staff.global_transform * point))
	for i in labels.size():
		jump = maxf(jump, prior[i].distance_to(bone(fall, labels[i])))
	assert(duration > 0.0 and jump < .002, "%s %.2f %s %f" % [actor.current_clip, phase, floor.rotation, jump])
	var skin: Dictionary = fall.fitted_fall.skin if actor.native_body == 24 else fall.pose_entry.skin
	var clearance := .0019 if actor.native_body == 24 else -.00001
	for i in 31:
		fall.animator.seek(duration * i / 30.0, true)
		assert(Ground.minimum_plane_gap(skin, fall.skeleton, fall.skeleton.global_transform,
			floor.position, floor.basis.y) >= clearance)
		if held_staff:
			var pole_gap: float = fall.staff_gap(fall.staff.global_transform, floor.basis.y)
			pole_gap += (fall.model.global_position - floor.position).dot(floor.basis.y)
			assert(pole_gap >= -.001, "%s staff death crossed the slope by %f m" % [actor.current_clip, pole_gap])
	var snapshot := Snapshot.capture(fall, fall.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "MultiMeshInstance3D", true, false).is_empty())
	if held_staff:
		assert(corpse.get_child_count() > 1)
	corpse.free()
	fall.free()
	return {"jump": jump}
