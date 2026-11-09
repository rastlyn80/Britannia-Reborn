extends "res://../scripts/test-gargoyle-kitsune-larva-corpses.gd"

const SLITH := 734
const MODERN := [[0, 0, 0, "Attack"], [0, 0, 1, "Attack2"], [0, 0, 2, "Attack"],
	[0, 1, 1, "Attack"], [0, 2, 1, "Attack"], [0, 9, 1, "Attack"], [0, 8, 1, "Attack2"],
	[2, 0, 0, "SlithSideRecoil"], [3, 0, 0, "Death"], [3, 0, 1, "Death2"],
	[4, 0, 0, "Hit"], [5, 0, 0, "SlithThreatLow"], [5, 0, 1, "SlithThreatRise"],
	[8, 0, 0, "SlithSettle"], [11, 0, 0, "Attack"], [14, 0, 0, "ReadyStance"], [15, 0, 0, "SlithScent"]]
const SUPPORTED := ["Death", "Death2", "Attack2", "SlithSideRecoil", "SlithThreatLow", "SlithThreatRise",
	"SlithSettle", "SlithScent"]
var newer := 0
var classic := 0
var peak_alternate_lift := 0.0

func run() -> void:
	var row := Registry.entry(SLITH)
	if "--active" in OS.get_cmdline_user_args():
		assert(row.classic_gesture_batch == "slith_actions")
	else:
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/slith_actions/prepared-client.json"))
		row = rows[0]
		Registry.entries[SLITH] = row
	assert(row.classic_action_categories.size() == 22 and not row.classic_action_categories.has("26"))
	for hue: int in [0, 0x1dc, 0x8035]:
		var corpse := Corpses.build(SLITH, hue)
		assert(corpse.get_meta("native_hue") == hue and corpse.get_meta("corpse_body") == SLITH)
		assert(corpse.get_meta("static_cadaver") and corpse.get_meta("death_clip") == "Death")
		corpse.free()
	var session := Game.new()
	root.add_child(session)
	session.set_process(false)
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for treatment: String in TREATMENTS:
			sample(session, plane, treatment, tilt.is_zero_approx())
		for group: int in [2, 3]:
			for phase: float in [0.08, 0.45, 0.78]:
				witness(plane, SLITH, group, phase)
		plane.free()
		await physics_frame
	assert(handoffs == 18 and checked == 3168 and classic == 198 and newer == 153)
	print("SLITH: ", checked, " decoded terrain and fall poses, ", classic, " Classic and ", newer,
		" newer selections, three static hues and ", handoffs, " corpse handoffs. Peak alternate lift ", peak_alternate_lift)
	quit()

func sample(session: Node, plane: StaticBody3D, treatment: String, check_keys: bool) -> void:
	var actor := Registry.create(SLITH)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(SLITH, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	assert(actor.skeleton.get_bone_count() == 28 and actor.contact.align_skinned_soles and actor.contact.iterations == 8)
	assert(actor.native_body == SLITH and actor.native_hue == 0x8035)
	if check_keys:
		Earlier.check_earlier_keys(player, actor.entry.classic_gesture_base_assets[treatment])
	var neutral: float = actor.model.position.y
	var anchor := actor.global_transform
	var routes: Dictionary = actor.entry.classic_action_categories
	for slot in range(22):
		reset_action(actor)
		var request := decode(session, SLITH, slot)
		assert(actor.receive_action(request) and actor.current_clip == routes[str(slot)])
		assert(actor.get_meta("native_action") == request and actor.entry.classic_action_categories == routes)
		classic += 1
	for action: Array in MODERN:
		reset_action(actor)
		var request := newer_packet(session, action[0], action[1], action[2])
		var clip: String = action[3]
		assert(actor.receive_action(request) and actor.current_clip == clip and actor.get_meta("native_action") == request)
		assert(is_equal_approx(actor.action_remaining, player.get_animation(clip).length))
		newer += 1
		if clip not in SUPPORTED:
			continue
		player.advance(0.15)
		for frame in 30:
			player.seek(player.current_animation_length * frame / 29.0, true)
			var gap := Ground.minimum_plane_gap(actor.skin, actor.skeleton, actor.skeleton.global_transform,
				plane.global_position, plane.global_basis.y.normalized())
			assert(actor.global_transform == anchor and gap >= 0.0015)
			if clip == "Death2":
				peak_alternate_lift = maxf(peak_alternate_lift, actor.model.position.y - neutral)
				assert(peak_alternate_lift < 0.11)
			checked += 1
	reset_action(actor)
	for gait: Array in [["Walk", 1.8], ["Run", 6.8]]:
		actor.play_gait(true, gait[1])
		assert(actor.current_clip == gait[0] and actor.contact.enabled)
	actor.free()

func reset_action(actor: Node3D) -> void:
	actor.restore_gesture()
	actor.model.position -= actor.fall.shift
	actor.fall.shift = Vector3.ZERO
	actor.fall.plane = {}
	actor.dead = false
	actor.action_remaining = 0.0
	actor.animator.stop()

func newer_packet(session: Node, kind: int, subaction: int, variation: int) -> Dictionary:
	var packet := PackedByteArray([0xe2])
	packet.append_array(Wire.uint_be(SLITH, 4))
	packet.append_array(Wire.uint_be(kind, 2))
	packet.append_array(Wire.uint_be(subaction, 2))
	packet.append(variation)
	session._handle(packet)
	return session.last_mobile_actions[SLITH]

func expected_fall(_body: int, group: int) -> String:
	return "Death2" if group == 3 else "Death"
