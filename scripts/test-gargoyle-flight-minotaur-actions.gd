# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-frost-through-gargoyle-actions.gd"

const HOLD_FAMILY := "gargoyle_flight_minotaur_actions"
const HOLD_BODIES := [755, 754, 262]

func run() -> void:
	Registry.load_index()
	var active := "--active" in OS.get_cmdline_user_args()
	var path := "res://../work/creatures/%s/prepared-client.json" % HOLD_FAMILY
	var rows: Array = HOLD_BODIES.map(func(body: int) -> Dictionary: return Registry.entry(body)) if active \
		else JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(rows.size() == HOLD_BODIES.size())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	for row: Dictionary in rows:
		var body := int(row.bodies[0].body)
		assert(row.get("classic_gesture_batch") == HOLD_FAMILY if active else row.family == HOLD_FAMILY)
		Registry.entries[body] = row
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		for treatment: String in row.assets:
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			if body == 262:
				verify_blocks(game, actor)
			else:
				verify_flight_handoff(game, actor)
			actor.free()
		for hue: int in [0, 53, 0x8035]:
			var cadaver := Corpses.build(body, hue)
			assert(cadaver.get_meta("corpse_body") == body and cadaver.get_meta("native_hue") == hue)
			assert(cadaver.get_meta("static_cadaver") and cadaver.find_children("*", "Skeleton3D", true, false).is_empty())
			cadaver.free()
			static_corpses += 1
	game.free()
	assert(classic == 18 and static_corpses == 9)
	print("GARGOYLE FLIGHT AND MINOTAUR BLOCKS: ", classic, " selections and ", static_corpses, " static corpse hues")
	quit()

func verify_flight_handoff(game: Node, actor: Node3D) -> void:
	var body: int = actor.native_body
	assert(actor.receive_action(decode(game, body, 21)))
	assert(actor.dead and actor.current_clip == "AirDeath" and not actor.contact.enabled)
	assert(is_equal_approx(actor.animator.get_animation("AirDeath").length, 1.1))
	actor._process(actor.action_remaining + 0.1)
	assert(not actor.animator.is_playing() and actor.current_clip == "AirDeath")
	assert(actor.receive_action(decode(game, body, 2)))
	assert(actor.dead and actor.current_clip == "Death")
	classic += 2

func verify_blocks(game: Node, actor: Node3D) -> void:
	var head: int = actor.skeleton.find_bone("bip01 head")
	var pelvis: int = actor.skeleton.find_bone("bip01 pelvis")
	assert(head >= 0 and pelvis >= 0)
	for group: int in [15, 16]:
		var clip := "BlockRight" if group == 15 else "BlockLeft"
		assert(actor.receive_action(decode(game, actor.native_body, group)))
		assert(actor.current_clip == clip and not actor.dead and actor.contact.enabled)
		actor.animator.stop()
		actor.animator.play(clip, 0.0)
		actor.animator.seek(actor.animator.current_animation_length * 0.45, true)
		var head_pose: Vector3 = actor.skeleton.get_bone_global_pose(head).origin
		var hips_pose: Vector3 = actor.skeleton.get_bone_global_pose(pelvis).origin
		var side: Vector3 = actor.skeleton.global_basis * (head_pose - hips_pose)
		assert(side.x < -0.25 if group == 15 else side.x > 0.25)
		classic += 1
