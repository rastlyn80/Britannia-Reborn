# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const AntFit := preload("bake-antlion-enhanced.gd")
const Body := 787
const Renderer := "res://Presentation/SourceEnhancedAntLionVisual.gd"


static func source_routes() -> Dictionary:
	var clips := AntFit.Clips
	return {"0": {"2": [clips[15], clips[15]], "5": [clips[1], clips[27]], "8": [clips[28]],
		"11": [clips[12], clips[12], clips[12]], "14": [clips[11]], "15": [clips[23]]}, "1": {"5": [clips[1]]}}


static func fitted_row(base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = source_routes()
	row.archive_grounded_gestures = AntFit.Clips.values()
	row.presentation_script = Renderer
	for treatment: String in row.assets:
		row.assets[treatment] = AntFit.Destination + "%d-%s.scn" % [Body, treatment]
	return row


func run() -> void:
	var base := Registry.entry(Body)
	var row := fitted_row(base)
	if "--installed" in OS.get_cmdline_user_args():
		assert(Installed.enable())
		row = Registry.entry(Body)
		assert(row.enhanced_source_action_groups == source_routes() and row.presentation_script == Renderer)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[Body] = {"serial": Body, "body": Body, "hue": 0x8035}
	var routes := source_routes()
	var packets := {}
	for type: String in routes["0"]:
		var options: Array = routes["0"][type]
		for variation in options.size():
			if not packets.has(options[variation]):
				packets[options[variation]] = decode(game, Body, int(type), variation)
	var report := {"poses": 0, "falls": 0, "routes": 0, "classic": 0, "gaits": 0,
		"gap": INF, "fall_gap": INF, "handoff": 0.0, "hashes": {}}
	for slope: Vector3 in Slopes:
		var floor := await create_floor(slope)
		for treatment: String in row.assets:
			var actor := create_actor(row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if slope == Vector3.ZERO:
				Giants.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
				var choices := check_routes(avatar, game, Body, routes)
				report.routes += choices.x
				report.classic += choices.y
				report.gaits += check_gaits(actor)
				report.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
			for clip: String in AntFit.Clips.values():
				start_antlion_clip(avatar, clip, packets)
				for sample in 31:
					seek(actor, sample / 30.0)
					var gap := minimum_gap(actor, floor, [actor.fitted_fall.skin])
					assert(gap >= .0018, "%s fell through the support plane by %.5f m" % [clip, gap])
					report.gap = minf(report.gap, gap)
					report.poses += 1
				for phase: float in [.19, .67]:
					start_antlion_clip(avatar, clip, packets)
					seek(actor, phase)
					var witness := check_fall(actor, floor, row)
					report.handoff = maxf(report.handoff, witness.handoff)
					report.fall_gap = minf(report.fall_gap, witness.gap)
					report.falls += 1
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	game.free()
	assert(report.poses == 3720 and report.falls == 240 and report.routes == 144
		and report.classic == 108 and report.gaits == 18)
	var receipt := FileAccess.open(AntFit.Destination + "runtime-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify(report, "\t"))
	receipt.close()
	print("ANTLION RUNTIME ", report)
	quit()


func create_actor(row: Dictionary, treatment: String) -> Node3D:
	var actor: Node3D = load(Renderer).new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(Body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func check_gaits(actor: Node3D) -> int:
	actor.action_remaining = 0.0
	for flags: int in [0, 64]:
		actor.set_native_combat_flags(flags)
		actor.play_gait(false, 0.0)
		assert(actor.current_clip == (AntFit.Clips[25] if flags == 0 else AntFit.Clips[1]))
		actor.play_gait(true, 2.0)
		assert(actor.current_clip == "Walk")
		actor.play_gait(true, 7.0)
		assert(actor.current_clip == "Run")
	return 6


func start_antlion_clip(avatar: Avatar, clip: String, packets: Dictionary) -> void:
	if packets.has(clip):
		start_action(avatar, packets[clip], clip)
	else:
		var actor := avatar.horse_visual
		actor.action_remaining = 0.0
		actor.set_native_combat_flags(0)
		actor.play_gait(false, 0.0)
		assert(actor.current_clip == clip)
		actor.animator.advance(.16)


func check_fall(source: Node3D, floor: StaticBody3D, row: Dictionary) -> Dictionary:
	var fallen := create_actor(row, source.treatment)
	fallen.global_transform = source.global_transform.rotated(Vector3.UP, .31)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	assert(fallen.begin_death_from(source) > 0.0 and fallen.current_clip == "Death")
	var jump := 0.0
	for joint: String in ["head", "large pincher l 02", "spine 01", "dummy03"]:
		jump = maxf(jump, landmark(source, joint).distance_to(landmark(fallen, joint)))
	assert(jump < .002, "%s fall handoff moved %.6f m" % [source.current_clip, jump])
	var gap := INF
	for sample in 31:
		seek(fallen, sample / 30.0)
		gap = minf(gap, minimum_gap(fallen, floor, [fallen.fitted_fall.skin]))
	assert(gap >= .0016)
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("corpse_body") == Body and corpse.get_meta("native_hue") == 0x8035
		and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	corpse.free()
	fallen.free()
	return {"handoff": jump, "gap": gap}
