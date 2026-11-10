# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Batch := preload("bake-stone-gargoyle-kitsune-enhanced.gd")
const Renderers := {67: "SourceEnhancedStoneGargoyleVisual.gd", 246: "SourceEnhancedBakeKitsuneVisual.gd"}


static func modes_for(body: int) -> Dictionary:
	if body == 67:
		return {"0": {"5": [Batch.Stone[26], Batch.Stone[27]], "8": [Batch.Stone[28]],
			"11": [Batch.Stone[12], Batch.Stone[12], Batch.Stone[12]], "15": [Batch.Stone[23]]},
			"1": {"5": [Batch.Stone[26]]}}
	var snap := Batch.Kitsune[4]
	return {"0": {"0": [snap, snap, snap, snap, snap, snap], "2": [Batch.Kitsune[15], Batch.Kitsune[15]],
		"5": [Batch.Kitsune[26], Batch.Kitsune[27]], "8": [Batch.Kitsune[28]], "11": [snap, snap, snap],
		"14": [Batch.Kitsune[25]], "15": [Batch.Kitsune[25]]}, "1": {"5": [Batch.Kitsune[26]]}}


static func row_for(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = modes_for(body)
	row.archive_grounded_gestures = (Batch.Stone if body == 67 else Batch.Kitsune).values()
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
	var reports := {}
	for body: int in Renderers:
		var base: Dictionary = bases[body]
		var row := Registry.entry(body) if installed else row_for(body, base)
		assert(row.enhanced_source_action_groups == modes_for(body))
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		reports[str(body)] = await review_batch(game, body, base, row)
		assert(reports[str(body)].poses == (2325 if body == 67 else 2790))
		assert(reports[str(body)].falls == (150 if body == 67 else 180))
	game.free()
	if not installed:
		var file := FileAccess.open(Batch.Destination + "terrain-receipt.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"bodies": reports, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
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


func review_batch(game: Node, body: int, base: Dictionary, row: Dictionary) -> Dictionary:
	var report := {"poses": 0, "falls": 0, "retained_air_falls": 0, "gap": INF, "fall_gap": INF,
		"jump": 0.0, "routes": 0, "classic": 0, "hashes": {}}
	var modes := modes_for(body)
	var packets := {}
	for mode: String in modes:
		for kind: String in modes[mode]:
			var clips: Array = modes[mode][kind]
			for variation in clips.size():
				if not packets.has(clips[variation]):
					packets[clips[variation]] = {"packet": decode(game, body, int(kind), variation),
						"flags": 64 if mode == "0" else 0}
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
			for clip: String in packets:
				start_fit(avatar, packets[clip], clip)
				for sample in 31:
					seek(actor, sample / 30.0)
					var gap := minimum_gap(actor, floor, skins)
					assert(gap >= .0018, "%d %s %.2f support gap %.6f" % [body, clip, sample / 30.0, gap])
					report.gap = minf(report.gap, gap)
					report.poses += 1
				for phase: float in [.18, .65]:
					start_fit(avatar, packets[clip], clip)
					seek(actor, phase)
					var result := check_batch_fall(actor, floor, body, row)
					report.jump = maxf(report.jump, result.jump)
					report.fall_gap = minf(report.fall_gap, result.gap)
					report.falls += 1
			if body == 67:
				actor.action_remaining = 0.0
				var flight := {"protocol": "classic", "action": 19, "body": body}
				assert(Dispatch.dispatch(avatar, flight, true, 64) and actor.current_clip == "Fly")
				actor.animator.advance(.16)
				seek(actor, .53)
				var result := check_batch_fall(actor, floor, body, row)
				assert(result.air)
				report.retained_air_falls += 1
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	print("STONE GARGOYLE AND BAKE KITSUNE RUNTIME ", body, " ", report)
	return report


func start_fit(avatar: Avatar, row: Dictionary, clip: String) -> void:
	var actor := avatar.horse_visual
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	actor.animator.advance(.18)
	if actor.has_method("set_native_combat_flags"):
		actor.set_native_combat_flags(row.flags)
	assert(Dispatch.dispatch(avatar, row.packet, true, row.flags) and actor.current_clip == clip)
	actor.animator.advance(.16)


func check_batch_fall(source: Node3D, floor: StaticBody3D, body: int, row: Dictionary) -> Dictionary:
	var fallen := actor_for(body, row, source.treatment)
	fallen.global_transform = source.global_transform.rotated(Vector3.UP, -.27)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	var duration: float = fallen.begin_death_from(source)
	assert(duration > 0.0 and fallen.current_clip in (["AirDeath", "Death"] if source.current_clip == "Fly" else ["Death"]))
	var jump := 0.0
	for joint: String in ["bip01 head", "bip01 l hand", "bip01 r hand"]:
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
	var air: bool = fallen.current_clip == "AirDeath"
	corpse.free()
	fallen.free()
	return {"jump": jump, "gap": gap, "air": air}
