extends "res://../scripts/test-gargoyle-kitsune-larva-corpses.gd"

const BATCH := "golem_raptor_juka_solen_actions"
const NewPacket := preload("res://../scripts/test-efreet-actions.gd")
const ROUTES := {
	752: {15: "IronBrace", 18: "IronReset"},
	766: {6: "BackhandStep", 15: "ArmoredBrace", 18: "ArmorGlance"},
	806: {15: "SolenRecoil"},
	782: {15: "SolenRecoil"},
}
const RAPTOR_REQUESTS := [
	[3, -1, 0, "Death2"], [15, -1, 0, "RaptorDuck"], [15, 15, 0, "RaptorLookBehind"],
	[26, 5, 0, "RaptorLookUp"], [27, 5, 1, "RaptorLowerHead"], [28, 8, 0, "RaptorSettle"],
]
var minimum := {}
var checked_poses := 0
var gait_checks := 0
var bow_checks := 0
var classic := 0
var newer := 0
var static_corpses := 0
var gait_falls := 0
var gait_fall_poses := 0
var peak_gait_handoff_error := 0.0

func run() -> void:
	Registry.load_index()
	var index := "res://local-art/creatures/accepted-index.json"
	var pin := FileAccess.get_sha256(index)
	var bodies := [752, 730, 734, 766, 806, 782]
	var active := "--active" in OS.get_cmdline_user_args()
	if not active:
		var path := "res://../work/creatures/golem_raptor_juka_solen_actions/prepared-client.json"
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(rows.size() == bodies.size())
		for row: Dictionary in rows:
			Registry.entries[int(row.bodies[0].body)] = row
	var session := Game.new()
	root.add_child(session)
	session.set_process(false)
	var expected_newer := 0
	for body: int in bodies:
		var row := Registry.entry(body)
		assert(row.get("classic_gesture_batch" if active else "family") == BATCH)
		session.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		for treatment: String in row.assets:
			verify_routes(session, body, treatment)
			expected_newer += row.new_action_categories.size()
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.get_meta("static_cadaver") and corpse.find_children("*", "AnimationPlayer", true, false).is_empty())
			corpse.free()
			static_corpses += 1
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for body: int in bodies:
			for treatment: String in Registry.entry(body).assets:
				sample_set(session, plane, body, treatment)
		for body: int in [730, 734]:
			for phase: float in [0.12, 0.42, 0.78]:
				verify_walk_fall(plane, body, phase)
		plane.free()
		await physics_frame
	assert(FileAccess.get_sha256(index) == pin and checked_poses == 4185 and gait_checks == 72 and bow_checks == 837)
	assert(classic == 288 and newer == expected_newer and static_corpses == 18 and minimum.values().min() > 0.0004,
		str([classic, newer, expected_newer, static_corpses, minimum]))
	assert(gait_falls == 18 and gait_fall_poses == 738 and peak_gait_handoff_error < 0.005)
	print("GOLEM, RAPTOR, SLITH, JUKA LORD AND SOLEN: ", checked_poses, " sampled poses, ", gait_checks,
		" gait selections, ", bow_checks, " equipped-bow samples, ", classic, " Classic and ", newer,
		" newer routes, ", static_corpses, " corpse hues. Minimum gaps ", minimum)
	print("PEACE WALK CORPSES: ", gait_falls, " decoded handoffs across ", gait_fall_poses,
		" poses. Largest entry difference ", peak_gait_handoff_error, " m")
	quit()

func verify_routes(session: Node, body: int, treatment: String) -> void:
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	var player: AnimationPlayer = actor.animator
	var earlier: Dictionary = actor.entry.classic_gesture_base_assets
	Earlier.check_earlier_keys(player, earlier.get(treatment, earlier.modern))
	for slot: String in actor.entry.classic_motion_references:
		actor.dead = false
		player.stop()
		var request := decode(session, body, int(slot))
		assert(request.body == body and actor.receive_action(request))
		assert(actor.current_clip == actor.entry.classic_action_categories[slot] and actor.get_meta("native_action") == request,
			str([body, slot, actor.current_clip]))
		classic += 1
	for kind: String in actor.entry.new_action_categories:
		actor.dead = false
		player.stop()
		var request := NewPacket.decode_new(session, body, int(kind), 0, 0)
		assert(request.body == body and actor.receive_action(request))
		assert(actor.current_clip == actor.entry.new_action_categories[kind] and actor.get_meta("native_action") == request)
		newer += 1
	actor.free()

func verify_walk_fall(plane: StaticBody3D, body: int, phase: float) -> void:
	var arena := Arena.new()
	root.add_child(arena)
	var session := Game.new()
	arena.add_child(session)
	session.set_process(false)
	var items := Items.new()
	arena.add_child(items)
	items.add_child(items.hint)
	items.session = session
	var deaths := Deaths.new()
	arena.add_child(deaths)
	deaths.configure(arena, session, items)
	deaths.set_process(false)
	var avatar := Avatar.new()
	avatar.initial_body = body
	arena.add_child(avatar)
	avatar.set_physics_process(false)
	var serial := 0x10e00 + body
	var corpse := 0x40010e00 + body
	var entity := {"serial": serial, "body": body, "hue": 53, "direction": 4, "flags": 0}
	preload("res://Presentation/NativeCreatureAppearance.gd").apply(avatar, entity, [], {})
	session.entities[serial] = entity
	arena.avatars[serial] = avatar
	var source: Node3D = avatar.horse_visual
	source.set_process(false)
	source.set_physics_process(false)
	source.contact.active = false
	var gait_player: AnimationPlayer = source.animator
	gait_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	source.play_gait(true, 2.0)
	assert(source.current_clip == ("RaptorPeaceWalk" if body == 730 else "SlithPeaceWalk"))
	gait_player.advance(0.2)
	gait_player.seek(gait_player.current_animation_length * phase, true)
	for sample in 24:
		source._physics_process(1.0 / 60.0)
		source.contact._process_modification_with_delta(1.0 / 60.0)
		source.skeleton.force_update_all_bone_transforms()
		source.contact.modification_processed.emit()
	var start := skinned_points(source)
	var holder := Node3D.new()
	items.add_child(holder)
	items.nodes[corpse] = holder
	assert(items._equine_corpse(holder, {"id": 0x2006, "amount": body, "hue": 53, "direction": 4}, corpse))
	var death := PackedByteArray([0xaf])
	for field: int in [serial, corpse, 0]:
		death.append_array(Wire.uint_be(field, 4))
	session._handle(death)
	assert(deaths.active.has(serial) and not avatar.visible and not holder.visible)
	var visual: Node3D = deaths.active[serial].visual
	visual.set_process(false)
	var player: AnimationPlayer = visual.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	assert(visual.current_clip == "Death" and visual.fall.plane.collider == plane)
	var difference := largest_difference(start, skinned_points(visual))
	assert(difference < 0.005, str([body, phase, difference, source.model.position, visual.model.position,
		source.get("clearance_lift"), visual.fall.shift]))
	peak_gait_handoff_error = maxf(peak_gait_handoff_error, difference)
	var floor := INF
	for frame in 41:
		player.seek(player.current_animation_length * frame / 40.0, true)
		floor = Ground.minimum_plane_gap(visual.fall.skin, visual.skeleton, visual.skeleton.global_transform,
			plane.global_position, plane.global_basis.y.normalized())
		assert(floor >= 0.0015 and visual.global_transform == source.global_transform, str([body, phase, frame, floor]))
		gait_fall_poses += 1
	var removal := PackedByteArray([0x1d])
	removal.append_array(Wire.uint_be(serial, 4))
	session._handle(removal)
	deaths._process(10.0)
	assert(not deaths.active.has(serial) and holder.visible)
	var cadaver := holder.get_node("CorpseVisual") as Node3D
	assert(cadaver.get_meta("corpse_body") == body and cadaver.get_meta("native_hue") == 53)
	assert(cadaver.get_meta("static_cadaver") and absf(static_floor(cadaver, plane) - floor) < 0.001)
	gait_falls += 1
	arena.free()

func sample_set(session: Node, plane: StaticBody3D, body: int, treatment: String) -> void:
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if body == 766:
		actor.set_equipment([{"id": 0x13b2, "layer": 2, "hue": 53}])
		assert(is_instance_valid(actor.bow_holder) and actor.bow_holder.visible)
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var normal := plane.global_basis.y.normalized()
	var anchor := actor.global_transform
	for warmup in 30:
		actor._physics_process(1.0 / 60.0)
		actor.contact._process_modification_with_delta(1.0 / 60.0)
		rig.force_update_all_bone_transforms()
		actor.contact.modification_processed.emit()
	var requests: Array = RAPTOR_REQUESTS.duplicate() if body == 730 else []
	if body in [730, 734]:
		var peaceful := "RaptorPeaceWalk" if body == 730 else "SlithPeaceWalk"
		for flags: int in [0, 0x40]:
			actor.set_native_combat_flags(flags)
			actor.play_gait(false, 0.0)
			assert(actor.current_clip == ("ReadyStance" if flags == 0 else "Idle"))
			actor.play_gait(true, 2.0)
			assert(actor.current_clip == (peaceful if flags == 0 else "Walk"))
			gait_checks += 2
		actor.set_native_combat_flags(0)
		actor.play_gait(true, 2.0)
		requests.append([22, -1, 0, peaceful])
	else:
		for slot: int in ROUTES[body]:
			requests.append([slot, -1, 0, ROUTES[body][slot]])
	for spec: Array in requests:
		if spec[0] == 22:
			actor.dead = false
			actor.action_remaining = 0.0
			actor.play_gait(true, 2.0)
		else:
			actor.dead = false
			player.stop()
			var packet := (decode(session, body, spec[0]) if spec[1] < 0 else
				NewPacket.decode_new(session, body, spec[1], 0, spec[2]))
			assert(actor.receive_action(packet))
		assert(actor.current_clip == spec[3])
		player.advance(0.15)
		for frame in 31:
			player.seek(player.current_animation_length * frame / 30.0, true)
			if not actor.dead:
				actor._physics_process(1.0 / 60.0)
				actor.contact._process_modification_with_delta(1.0 / 60.0)
				rig.force_update_all_bone_transforms()
				actor.contact.modification_processed.emit()
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
			assert(is_finite(gap) and actor.global_transform == anchor)
			var key := "%d:%d" % [body, spec[0]]
			minimum[key] = minf(minimum.get(key, INF), gap)
			if body == 766:
				var grasp := rig.to_global(rig.get_bone_global_pose(actor.left_grasp).origin)
				assert(actor.bow_holder.visible and actor.bow_holder.global_position.distance_to(grasp) < 0.0005)
				assert(actor.applied_draw.is_zero_approx())
				bow_checks += 1
			checked_poses += 1
	actor.free()
