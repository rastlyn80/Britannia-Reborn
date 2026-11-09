extends "res://../scripts/test-gargoyle-kitsune-larva-corpses.gd"

const CAPTAIN := 7
const ACTIONS := {2:"Death", 3:"Death2", 4:"Attack", 5:"Attack2", 6:"Attack3", 10:"Hit",
	11:"Pillage", 15:"CaptainHighGuard", 16:"CaptainLowGuard", 17:"CaptainAxeSignal", 18:"CaptainAxeCheck"}

func run() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var row := Registry.entry(CAPTAIN).duplicate(true)
		row.assets = {}
		for treatment: String in TREATMENTS:
			row.assets[treatment] = "res://local-art/creatures/orc-captain-actions-%s.scn" % treatment
		row.classic_action_categories = {}
		for slot: int in ACTIONS:
			row.classic_action_categories[str(slot)] = ACTIONS[slot]
		row.presentation_script = "res://Presentation/OrcCaptainActionsVisual.gd"
		row.grounded_gestures = ["Attack", "Attack2", "Attack3", "Hit", "Pillage", "CaptainHighGuard",
			"CaptainLowGuard", "CaptainAxeSignal", "CaptainAxeCheck"]
		Registry.entries[CAPTAIN] = row
	var session := Game.new()
	root.add_child(session)
	session.set_process(false)
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(CAPTAIN, hue)
		assert(corpse.get_meta("corpse_body") == CAPTAIN and corpse.get_meta("native_hue") == hue)
		assert(corpse.find_child("OrcCaptainAxe", true, false) != null)
		corpse.free()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for treatment: String in TREATMENTS:
			sample_terrain(session, plane, treatment)
		witness(plane, CAPTAIN, 17, 0.0)
		for phase: float in [0.08, 0.45, 0.78]:
			for group: int in [2, 3]:
				witness(plane, CAPTAIN, group, phase)
		plane.free()
		await physics_frame
	assert(handoffs == 21 and checked == 2544)
	print("ORC CAPTAIN: ", checked, " decoded terrain poses including ", handoffs, " corpse handoffs")
	quit()

func expected_fall(_body: int, group: int) -> String:
	return "Death2" if group == 3 else "Death"

func sample_terrain(session: Node, plane: StaticBody3D, treatment: String) -> void:
	var actor := Registry.create(CAPTAIN)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(CAPTAIN, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var axe := actor.model.find_child("OrcCaptainAxe", true, false) as MeshInstance3D
	assert(axe.get_surface_override_material(0) == null and actor.skeleton.get_bone_count() == 38)
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for slot: int in ACTIONS:
		actor.model.position -= actor.fall.shift
		actor.fall.shift = Vector3.ZERO
		actor.fall.plane = {}
		actor.restore_gesture()
		actor.dead = false
		player.stop()
		assert(actor.receive_action(decode(session, CAPTAIN, slot)) and actor.current_clip == ACTIONS[slot])
		player.advance(0.15)
		for step in 17:
			player.seek(player.current_animation_length * step / 16.0, true)
			var gap := Ground.minimum_plane_gap(actor.skin, actor.skeleton, actor.skeleton.global_transform,
				plane.global_position, plane.global_basis.y.normalized())
			assert(gap >= 0.0015 and actor.global_position == Vector3.ZERO and actor.native_hue == 0x8035,
				"Orc Captain %s slot %d step %d: %s" % [treatment, slot, step, gap])
			checked += 1
	actor.free()
