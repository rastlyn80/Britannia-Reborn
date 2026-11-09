extends "res://../scripts/test-gargoyle-kitsune-larva-corpses.gd"

const ROUTES := {
	259: {15: "BlockLeft", 16: "BlockRight", 17: "GrizzleBreath", 18: "Fidget"},
	264: {15: "BlockLeft", 16: "BlockRight", 17: "ChangelingWingRoll", 18: "Fidget"},
	72: {5: "ForelegThrust", 6: "PincerOverhead", 13: "MatriarchBurst", 15: "PincerBrace",
		16: "PincerRecoil", 18: "MandibleTwitch"},
}
const MODERN := {259: {"0": "Attack", "2": "BlockLeft", "3": "Death", "4": "Hit", "14": "GrizzleAntlerCheck"},
	264: {"0": "Attack", "2": "BlockLeft", "3": "Death", "4": "Hit", "14": "Pillage"},
	72: {"0": "Attack", "2": "PincerBrace", "3": "Death", "4": "Hit", "11": "TerathanCast", "14": "MatriarchDip"}}
const BONE_COUNTS := {259: 39, 264: 35, 72: 62}
const Efreet := preload("res://../scripts/test-efreet-actions.gd")
var classic := 0
var effects_checked := 0
var living_poses := 0
var newer := 0
var gap_by_clip := {}

func run() -> void:
	var session := Game.new()
	root.add_child(session)
	session.set_process(false)
	Registry.load_index()
	var active := "--active" in OS.get_cmdline_user_args()
	if not active:
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(
			"res://../work/creatures/ranked_classic_actions/prepared-client.json"))
		assert(rows.size() == ROUTES.size())
		for row: Dictionary in rows:
			Registry.entries[int(row.bodies[0].body)] = row
	for body: int in ROUTES:
		var row := Registry.entry(body)
		assert(row.get("classic_gesture_batch" if active else "family") == "ranked_classic_actions")
		session.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.get_meta("static_cadaver") and corpse.find_children("*", "GPUParticles3D", true, false).is_empty())
			corpse.free()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for body: int in ROUTES:
			for treatment: String in TREATMENTS:
				sample(session, plane, body, treatment, tilt.is_zero_approx())
			for group: int in [2, 3]:
				for phase: float in [0.08, 0.45, 0.78]:
					witness(plane, body, group, phase)
		plane.free()
		await physics_frame
	assert(handoffs == 54 and checked == 2214 and living_poses == 3906 and effects_checked == 36 and newer == 279 and classic == 378,
		"Incomplete action witnesses: %s" % str([handoffs, checked, living_poses, effects_checked, newer, classic]))
	print("GRIZZLE, CHANGELING AND MATRIARCH: ", living_poses, " terrain gesture poses, ", effects_checked, " burst phases, ",
		handoffs, " decoded handoffs / ", checked, " fall poses, ", classic, " Classic and ", newer, " newer selections. Minimum gaps ", gap_by_clip)
	quit()

func sample(session: Node, plane: StaticBody3D, body: int, treatment: String, exact: bool) -> void:
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var rig: Skeleton3D = actor.skeleton
	assert(rig.get_bone_count() == BONE_COUNTS[body] and actor.native_body == body and actor.native_hue == 0x8035,
		"%d %s has %d bones, native body %d and hue %d" % [body, treatment, rig.get_bone_count(), actor.native_body, actor.native_hue])
	if exact:
		Earlier.check_earlier_keys(player, actor.entry.classic_gesture_base_assets[treatment])
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var normal := plane.global_basis.y.normalized()
	var anchor := actor.global_transform
	for slot: String in actor.entry.classic_action_categories:
		reset_action(actor)
		var request := decode(session, body, int(slot))
		assert(request.body == body and actor.receive_action(request))
		assert(actor.current_clip == actor.entry.classic_action_categories[slot] and actor.get_meta("native_action") == request)
		classic += 1
	reset_action(actor)
	for group: int in ROUTES[body]:
		var request := decode(session, body, group)
		var clip: String = ROUTES[body][group]
		player.stop()
		assert(actor.receive_action(request) and actor.current_clip == clip and actor.get_meta("native_action") == request)
		player.advance(0.15)
		for frame in 31:
			player.seek(player.current_animation_length * frame / 30.0, true)
			actor._physics_process(1.0 / 60.0)
			if actor.contact.enabled:
				actor.contact._process_modification_with_delta(1.0 / 60.0)
				rig.force_update_all_bone_transforms()
				actor.contact.modification_processed.emit()
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
			assert(is_finite(gap) and actor.global_transform == anchor and gap >= 0.0004)
			var key := "%d:%s" % [body, clip]
			gap_by_clip[key] = minf(gap, float(gap_by_clip.get(key, INF)))
			if body == 72 or clip == "ChangelingWingRoll":
				assert(gap >= 0.0015, "%d %s at %d: %s" % [body, clip, frame, gap])
			living_poses += 1
		if clip == "MatriarchBurst":
			check_burst(actor)
	var cases := []
	for kind: String in MODERN[body]:
		cases.append([int(kind), 0, 0, MODERN[body][kind]])
	cases.append_array([[0, 0, 1, actor.entry.classic_action_categories["5"]], [0, 2, 1, "Attack"],
		[0, 9, 1, "Attack"], [3, 0, 1, "Death2"], [0, 8, 1, actor.entry.classic_action_categories["5"]]])
	for spec: Array in cases:
		reset_action(actor)
		var action := Efreet.decode_new(session, body, spec[0], spec[1], spec[2])
		assert(action.body == body and actor.receive_action(action) and actor.current_clip == spec[3] and actor.get_meta("native_action") == action)
		assert(is_equal_approx(actor.action_remaining, player.get_animation(spec[3]).length))
		newer += 1
	actor.free()

func reset_action(actor: Node3D) -> void:
	if actor.has_method("restore_gesture"):
		actor.restore_gesture()
	actor.model.position -= actor.fall.shift
	actor.fall.shift = Vector3.ZERO
	actor.fall.plane = {}
	actor.dead = false
	actor.action_remaining = 0.0
	actor.animator.stop()

func check_burst(actor: Node3D) -> void:
	for probe: Array in [[0.48, true], [0.58, false], [0.72, true], [0.90, false]]:
		actor.animator.seek(actor.animator.current_animation_length * float(probe[0]), true)
		actor._process(0.0)
		assert(not actor.arc.visible)
		for motes in actor.release_motes:
			assert(motes.emitting == probe[1])
		effects_checked += 1

func expected_fall(_body: int, group: int) -> String:
	return "Death2" if group == 3 else "Death"
