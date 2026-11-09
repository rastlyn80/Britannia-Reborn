# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-frost-through-gargoyle-actions.gd"

const CENTAUR_BATCH := "centaur_through_essence_actions"
const SLOTS := {101: [6, 15, 16], 146: [15, 16, 18], 255: [11, 15, 16, 18], 262: [18], 273: [15, 16, 18]}

func run() -> void:
	Registry.load_index()
	var rows: Array = []
	var index := "res://local-art/creatures/accepted-index.json"
	var digest := FileAccess.get_sha256(index)
	if "--active" in OS.get_cmdline_user_args():
		for body: int in SLOTS:
			var row := Registry.entry(body)
			assert(row.get("classic_gesture_batch") == CENTAUR_BATCH)
			rows.append(row)
	else:
		var path := "res://../work/creatures/%s/prepared-client.json" % CENTAUR_BATCH
		rows = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(rows.size() == SLOTS.size())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var expected_ground := 0
	for row: Dictionary in rows:
		var body := int(row.bodies[0].body)
		Registry.entries[body] = row
		game.entities[body] = {"serial": body, "body": body, "hue": 53}
		for treatment: String in row.assets:
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			for group: int in SLOTS[body]:
				assert(actor.receive_action(decode(game, body, group)), str([body, group]))
				assert(actor.current_clip == row.classic_action_categories[str(group)])
				classic += 1
			assert(not actor.dead)
			if body == 273:
				check_essence(actor)
			assert(actor.receive_action(decode(game, body, 2)) and actor.current_clip == "Death")
			actor.free()
			expected_ground += row.archive_grounded_gestures.size() * 31 * SLOPES.size()
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.get_meta("static_cadaver") and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			corpse.free()
			static_corpses += 1
	game.free()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for row: Dictionary in rows:
			for treatment: String in row.assets:
				sample_ranked_ground(plane, int(row.bodies[0].body), treatment)
		plane.free()
		await physics_frame
	assert(classic == 42 and static_corpses == 15 and ground_poses == expected_ground)
	assert(FileAccess.get_sha256(index) == digest)
	print("CENTAUR THROUGH ESSENCE: ", classic, " decoded selections, ", ground_poses, " terrain poses, ",
		static_corpses, " corpse hues, minimum ", lowest)
	quit()

func check_essence(actor: Node3D) -> void:
	var energy: int = actor.skeleton.find_bone("EnergyRoot")
	assert(energy >= 0)
	var scales := []
	for clip: String in ["Idle", "EssenceCompactRecoil", "EssenceTallRecoil", "EssenceBillow"]:
		actor.animator.stop()
		actor.animator.play(clip, 0.0)
		var fraction := 0.0 if clip == "Idle" else 1.0 / 6.0 if clip == "EssenceBillow" else 0.25
		actor.animator.seek(actor.animator.current_animation_length * fraction, true)
		scales.append(actor.skeleton.get_bone_pose_scale(energy))
	var base: Vector3 = scales[0]
	assert((scales[1] / base).is_equal_approx(Vector3(0.6047, 0.6087, 0.6047)))
	assert((scales[2] / base).is_equal_approx(Vector3(0.6211, 0.587, 0.6211)))
	assert((scales[3] / base).is_equal_approx(Vector3(0.7907, 0.7895, 0.7907)))
