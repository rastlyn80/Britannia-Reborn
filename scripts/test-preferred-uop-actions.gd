# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-frost-through-gargoyle-actions.gd"

const ALTERNATES := {
	753: ["UopGargoyleGuard", "UopGargoyleStand", "UopGargoyleLunge", "UopGargoyleStep"],
	831: ["UopParrotWingTuck"],
}
const RENDERERS := {
	753: "res://Presentation/ArchiveSourcePreservingGestureVisual.gd",
	831: "res://Presentation/ArchiveOccurrenceGestureVisual.gd",
}
const PREVIEW_ACTIONS := {
	753: {"2": "UopGargoyleGuard", "8": "UopGargoyleStep", "14": "Pillage", "15": "UopGargoyleStand"},
	831: {"2": "Idle", "8": "Idle", "11": "Idle", "14": "Idle", "15": "Idle"},
}

func run() -> void:
	Registry.load_index()
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	for body: int in ALTERNATES:
		var row := Registry.entry(body).duplicate(true)
		var active := "--active" in OS.get_cmdline_user_args()
		if active:
			assert(row.has("preferred_uop_native_sha256"))
		row.presentation_script = RENDERERS[body]
		row.archive_grounded_gestures = ALTERNATES[body]
		row.archive_align_gesture_slope = true
		var routes: Dictionary = PREVIEW_ACTIONS[body]
		if active:
			assert(routes.keys().all(func(kind: String) -> bool: return row.new_action_categories[kind] == routes[kind]))
		else:
			row.new_action_categories = row.get("new_action_categories", {}).merged(routes, true)
		game.entities[body] = {"serial": body, "body": body, "hue": 53}
		for treatment: String in row.assets:
			var candidate := "res://local-art/creatures/preferred-uop-%d-actions-%s.scn" % [body, treatment]
			if active:
				assert(row.assets[treatment] == candidate)
			else:
				row.assets[treatment] = candidate
		Registry.entries[body] = row
		for treatment: String in row.assets:
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			for kind: String in routes:
				for variation in [0, 1]:
					assert(actor.receive_action(NewPacket.decode_new(game, body, int(kind), 0, variation)))
					assert(actor.current_clip == routes[kind] and not actor.dead)
					newer += 1
			actor.free()
		for hue in [0, 53, 0x8035]:
			var cadaver := Corpses.build(body, hue)
			assert(cadaver.get_meta("corpse_body") == body and cadaver.get_meta("native_hue") == hue)
			assert(cadaver.get_meta("static_cadaver") and cadaver.find_children("*", "Skeleton3D", true, false).is_empty())
			cadaver.free()
			static_corpses += 1
	game.free()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for body: int in ALTERNATES:
			for treatment: String in Registry.entry(body).assets:
				sample_ranked_ground(plane, body, treatment)
		plane.free()
		await physics_frame
	assert(newer == 54 and ground_poses == 1395 and static_corpses == 6)
	print("PREFERRED UOP ACTIONS: ", newer, " decoded selections, ",
		ground_poses, " terrain poses, ", static_corpses, " corpse hues, minimum ", lowest)
	quit()
