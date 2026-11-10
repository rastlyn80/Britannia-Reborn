# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Batch := preload("bake-widow-juka-enhanced.gd")
const Renderers := {157: "SourceEnhancedBlackWidowVisual.gd", 765: "SourceEnhancedJukaMageVisual.gd"}
const Bodies := [157, 765]
const Modes := {
	157: {"0": {"5": [Batch.Widow[26], Batch.Widow[27]], "8": [Batch.Widow[28]],
		"11": [Batch.Widow[12], Batch.Widow[12], Batch.Widow[12]], "15": [Batch.Widow[23]]},
		"1": {"5": [Batch.Widow[26]]}},
	765: {"0": {"8": [Batch.Mage[28]], "15": [Batch.Mage[23]]}, "1": {}},
}
const Cases := {157: {12: [11, 0], 23: [15, 0], 26: [5, 0], 27: [5, 1], 28: [8, 0]},
	765: {23: [15, 0], 28: [8, 0]}}


static func row_for(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = Modes[body]
	row.archive_grounded_gestures = (Batch.Widow if body == 157 else Batch.Mage).values()
	for treatment: String in row.assets:
		row.assets[treatment] = Batch.Destination + "%d-%s.scn" % [body, treatment]
	return row


func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var bases := {}
	for body: int in Bodies:
		bases[body] = Registry.entry(body)
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	var result := {}
	for body: int in Bodies:
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		result[str(body)] = await exercise(game, body, bases[body], installed)
		var summary: Dictionary = result[str(body)]
		assert(summary.poses == (2325 if body == 157 else 930))
		assert(summary.falls == (150 if body == 157 else 60))
		assert(summary.routes == (96 if body == 157 else 48))
		assert(summary.classic == (72 if body == 157 else 36))
		assert(summary.growth == (15 if body == 157 else 0))
	game.free()
	if not installed:
		var receipt := FileAccess.open(Batch.Destination + "runtime-receipt.json", FileAccess.WRITE)
		assert(receipt != null)
		receipt.store_string(JSON.stringify(result, "\t"))
		receipt.close()
	quit()


func create_actor(body: int, row: Dictionary, treatment: String) -> Node3D:
	var actor: Node3D
	if Installed.enabled:
		actor = Registry.create(body)
	else:
		var renderer := load(Batch.Destination + Renderers[body]) as GDScript
		actor = renderer.new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func exercise(game: Node, body: int, base: Dictionary, installed: bool) -> Dictionary:
	var row := Registry.entry(body) if installed else row_for(body, base)
	assert(row.enhanced_source_action_groups == Modes[body])
	var clips := Batch.Widow if body == 157 else Batch.Mage
	var report := {"poses": 0, "falls": 0, "growth": 0, "gap": INF, "fall_gap": INF, "jump": 0.0,
		"routes": 0, "classic": 0, "hashes": {}}
	for slope: Vector3 in Slopes:
		var floor := await create_floor(slope)
		for treatment: String in row.assets:
			var actor := create_actor(body, row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			var skins := body_skins(actor)
			if slope == Vector3.ZERO:
				Batch.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
				var counts := check_routes(avatar, game, body, Modes[body])
				report.routes += counts.x
				report.classic += counts.y
				report.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
			for group: int in Cases[body]:
				var code: Array = Cases[body][group]
				var packet := decode(game, body, code[0], code[1])
				var clip: String = clips[group]
				start_action(avatar, packet, clip)
				for sample in 31:
					seek(actor, sample / 30.0)
					var gap := minimum_gap(actor, floor, skins)
					assert(gap >= .0016, "%d %s %s at %d has floor gap %.6f" % [body, treatment, clip, sample, gap])
					report.gap = minf(report.gap, gap)
					report.poses += 1
				for phase: float in [.15, .63]:
					start_action(avatar, packet, clip)
					seek(actor, phase)
					var summary := finish_fall(actor, floor, row)
					report.jump = maxf(report.jump, summary.jump)
					report.fall_gap = minf(report.fall_gap, summary.gap)
					report.falls += 1
				if body == 157 and group == 23:
					check_growth(avatar, floor, skins, packet, clip)
					report.growth += 1
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	print("GIANT BLACK WIDOW AND JUKA MAGE RUNTIME ", body, " ", report)
	return report


func check_growth(avatar: Avatar, floor: StaticBody3D, skins: Array[Dictionary], packet: Dictionary, clip: String) -> void:
	var actor := avatar.horse_visual
	var root_joint: int = actor.skeleton.find_bone("__root")
	start_action(avatar, packet, clip)
	seek(actor, 0.0)
	assert(actor.skeleton.get_bone_pose_scale(root_joint).x < .08)
	seek(actor, .29)
	var previous: float = actor.skeleton.get_bone_pose_scale(root_joint).x
	assert(previous > .20 and previous < .90)
	assert(Classic.dispatch(avatar, {"protocol": "classic", "body": 157, "action": 4}))
	actor.animator.advance(.14)
	assert(actor.current_clip == "Attack" and actor.growth.active)
	for frame in 20:
		actor.animator.advance(1.0 / 60.0)
		var scale: float = actor.skeleton.get_bone_pose_scale(root_joint).x
		assert(scale >= previous - .001 and scale <= 1.001)
		previous = scale
	assert(not actor.growth.active and is_equal_approx(previous, 1.0))
	assert(minimum_gap(actor, floor, skins) >= .0016)


func finish_fall(source: Node3D, floor: StaticBody3D, row: Dictionary) -> Dictionary:
	var body: int = source.native_body
	var fallen := create_actor(body, row, source.treatment)
	fallen.global_transform = source.global_transform.rotated(Vector3.UP, -.31)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	assert(fallen.begin_death_from(source) > 0.0 and fallen.current_clip == "Death")
	var joints := ["bone01", "bone02", "bone22", "bone34"] if body == 157 else [
		"bip01 head", "bip01 l hand", "bip01 r foot"]
	var jump := 0.0
	for joint: String in joints:
		jump = maxf(jump, landmark(source, joint).distance_to(landmark(fallen, joint)))
	assert(jump < .002, "%d %s handoff displaced %.6f m" % [body, source.current_clip, jump])
	var gap := INF
	var skins := body_skins(fallen)
	for sample in 31:
		seek(fallen, sample / 30.0)
		gap = minf(gap, minimum_gap(fallen, floor, skins))
	assert(gap >= .0016, "%s fall has gap %.6f" % [source.current_clip, gap])
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	corpse.free()
	fallen.free()
	return {"jump": jump, "gap": gap}

