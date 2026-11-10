# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Batch := preload("bake-grizzle-changeling-enhanced.gd")
const Renderers := {259: "SourceEnhancedGrizzleChangelingVisual.gd", 264: "SourceEnhancedGrizzleChangelingVisual.gd"}


static func modes_for(body: int) -> Dictionary:
	var clips: Dictionary = Batch.Grizzle if body == 259 else Batch.Changeling
	return {"0": {"5": [clips[26], clips[27]], "8": [clips[28]],
		"11": [clips[12], clips[12], clips[12]], "15": [clips[23]]}, "1": {"5": [clips[26]]}}


static func row_for(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = modes_for(body)
	row.archive_grounded_gestures = (Batch.Grizzle if body == 259 else Batch.Changeling).values()
	if body == 264:
		row.flight_falls_back_to_combat = true
	for treatment: String in row.assets:
		row.assets[treatment] = Batch.Destination + "%d-%s.scn" % [body, treatment]
	return row


func run() -> void:
	var installed := "--installed" in OS.get_cmdline_user_args()
	var bases := {}
	for body: int in Renderers:
		bases[body] = Registry.entry(body)
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var bodies := {}
	for body: int in Renderers:
		var row := Registry.entry(body) if installed else row_for(body, bases[body])
		assert(row.enhanced_source_action_groups == modes_for(body))
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		bodies[str(body)] = await review(game, body, bases[body], row)
		var expected_clips: int = (Batch.Grizzle if body == 259 else Batch.Changeling).size()
		assert(bodies[str(body)].poses == expected_clips * 3 * Slopes.size() * 31)
		assert(bodies[str(body)].falls == expected_clips * 3 * Slopes.size() * 2)
	game.free()
	if not installed:
		var file := FileAccess.open(Batch.Destination + "terrain-receipt.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"bodies": bodies, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	quit()


func actor_for(body: int, row: Dictionary, treatment: String) -> Node3D:
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


func review(game: Node, body: int, base: Dictionary, row: Dictionary) -> Dictionary:
	var report := {"poses": 0, "falls": 0, "gap": INF, "fall_gap": INF, "jump": 0.0, "routes": 0,
		"classic": 0, "hashes": {}, "hover_peak": 0.0, "hover_samples": 0, "flight_comparisons": 0}
	var changeling := body == 264
	var modes := modes_for(body)
	var packets := {}
	for kind: String in modes["0"]:
		var clips: Array = modes["0"][kind]
		for variation in clips.size():
			packets[clips[variation]] = decode(game, body, int(kind), variation)
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := actor_for(body, row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			var skins := body_skins(actor)
			if tilt == Vector3.ZERO:
				var baked := (load(row.assets[treatment]) as PackedScene).instantiate()
				var baked_player := baked.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
				Batch.verify_base_clips(baked_player, Registry.asset_path(base, treatment))
				baked.free()
				report.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				var counts := check_routes(avatar, game, body, modes)
				report.routes += counts.x
				report.classic += counts.y
				if changeling:
					report.flight_comparisons += check_flight_fallback(avatar, game, modes["0"])
			for clip: String in packets:
				start_fit(avatar, packets[clip], clip)
				for sample in 31:
					var phase := sample / 30.0
					seek(actor, phase)
					var gap := minimum_gap(actor, floor, skins)
					assert(gap >= .0018, "%d %s %.2f support gap %.6f" % [body, clip, phase, gap])
					report.gap = minf(report.gap, gap)
					report.poses += 1
					if changeling:
						report.hover_peak = maxf(report.hover_peak, gap)
						if gap >= .08:
							report.hover_samples += 1
				for phase: float in [.18, .65]:
					start_fit(avatar, packets[clip], clip)
					seek(actor, phase)
					var result := check_fit_fall(actor, floor, body, row)
					report.jump = maxf(report.jump, result.jump)
					report.fall_gap = minf(report.fall_gap, result.gap)
					report.falls += 1
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	print("INTERRED GRIZZLE AND CHANGELING RUNTIME ", body, " ", report)
	return report


func check_flight_fallback(avatar: Avatar, game: Node, combat: Dictionary) -> int:
	var count := 0
	for flags: int in [4, 68]:
		for kind: String in combat:
			var choices: Array = combat[kind]
			for variation: int in [0, 1, 127]:
				assert(Dispatch.dispatch(avatar, decode(game, 264, int(kind), variation), true, flags))
				assert(avatar.horse_visual.current_clip == choices[variation % choices.size()])
				count += 1
	return count


func start_fit(avatar: Avatar, packet: Dictionary, clip: String) -> void:
	var actor := avatar.horse_visual
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	actor.animator.advance(.24)
	assert(Dispatch.dispatch(avatar, packet, true, 64) and actor.current_clip == clip)
	actor.animator.advance(.16)


func check_fit_fall(source: Node3D, floor: StaticBody3D, body: int, row: Dictionary) -> Dictionary:
	var fallen := actor_for(body, row, source.treatment)
	fallen.global_transform = source.global_transform.rotated(Vector3.UP, -.27)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	var duration: float = fallen.begin_death_from(source)
	assert(duration > 0.0 and fallen.current_clip == "Death")
	var jump := 0.0
	var joints := ["bip01 head", "bip01 l foot", "bip01 r hand"] if body == 259 else [
		"bip01 head", "bip01 l foot", "bone_wingright"]
	for joint: String in joints:
		jump = maxf(jump, landmark(source, joint).distance_to(landmark(fallen, joint)))
	assert(jump < .002, "%d %s handoff displaced %.6f m" % [body, source.current_clip, jump])
	var gap := INF
	var skins := body_skins(fallen)
	for sample in 31:
		seek(fallen, sample / 30.0)
		gap = minf(gap, minimum_gap(fallen, floor, skins))
	assert(gap >= .0018, "%d %s fall has gap %.6f" % [body, source.current_clip, gap])
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	corpse.free()
	fallen.free()
	return {"jump": jump, "gap": gap}
