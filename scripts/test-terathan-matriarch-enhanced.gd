# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Batch := preload("bake-terathan-matriarch-enhanced.gd")
const Body := 72
const Modes := {"0": {"5": [Batch.Clips[26], Batch.Clips[27]], "8": [Batch.Clips[28]], "15": [Batch.Clips[23]]},
	"1": {"5": [Batch.Clips[26]]}}
const Cases := {23: [15, 0], 26: [5, 0], 27: [5, 1], 28: [8, 0]}


func run() -> void:
	var base := Registry.entry(Body)
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	var row := Registry.entry(Body) if installed else base.duplicate(true)
	if not installed:
		for treatment: String in row.assets:
			row.assets[treatment] = Batch.Destination + "%d-%s.scn" % [Body, treatment]
		row.enhanced_source_action_groups = Modes
		row.archive_grounded_gestures = Batch.Clips.values()
		row.grounded_gestures.append_array(row.archive_grounded_gestures)
	assert(row.enhanced_source_action_groups == Modes)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[Body] = {"serial": Body, "body": Body, "hue": 0x8035}
	var report := {"poses": 0, "falls": 0, "gap": INF, "fall_gap": INF, "jump": 0.0, "routes": 0, "classic": 0, "hashes": {}}
	for slope: Vector3 in Slopes:
		var floor := await create_floor(slope)
		for treatment: String in row.assets:
			var actor := matriarch(row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			var skins := body_skins(actor)
			if slope == Vector3.ZERO:
				Batch.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
				var choices := check_routes(avatar, game, Body, Modes)
				report.routes += choices.x
				report.classic += choices.y
				report.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				check_cast(avatar, game)
			for group: int in Cases:
				var packet := decode(game, Body, Cases[group][0], Cases[group][1])
				var clip: String = Batch.Clips[group]
				start_action(avatar, packet, clip)
				for sample in 31:
					seek(actor, sample / 30.0)
					var gap := minimum_gap(actor, floor, skins)
					assert(gap >= .0018, "%s %s at %d has floor gap %.6f" % [treatment, clip, sample, gap])
					report.gap = minf(report.gap, gap)
					report.poses += 1
				for phase: float in [.18, .66]:
					start_action(avatar, packet, clip)
					seek(actor, phase)
					var result := interrupted_fall(actor, floor, row)
					report.jump = maxf(report.jump, result.jump)
					report.fall_gap = minf(report.fall_gap, result.gap)
					report.falls += 1
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	game.free()
	assert(report.poses == 1860 and report.falls == 120 and report.routes == 72 and report.classic == 54)
	print("TERATHAN MATRIARCH RUNTIME ", report)
	if not installed:
		var receipt := FileAccess.open(Batch.Destination + "matriarch-runtime-receipt.json", FileAccess.WRITE)
		assert(receipt != null)
		receipt.store_string(JSON.stringify(report, "\t"))
		receipt.close()
	quit()


func matriarch(row: Dictionary, treatment: String) -> Node3D:
	var actor: Node3D
	if Installed.enabled:
		actor = Registry.create(Body)
	else:
		var renderer := load(Batch.Destination + "SourceEnhancedTerathanMatriarchVisual.gd") as GDScript
		actor = renderer.new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(Body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func check_cast(avatar: Avatar, game: Node) -> void:
	var actor := avatar.horse_visual
	var packet := decode(game, Body, 11, 0)
	assert(Dispatch.dispatch(avatar, packet, true, 64) and actor.current_clip == "TerathanCast")
	actor.animator.advance(.16)
	seek(actor, .38)
	actor._process(.001)
	assert(actor.held_motes[0].emitting and actor.held_motes[1].emitting)


func interrupted_fall(source: Node3D, floor: StaticBody3D, row: Dictionary) -> Dictionary:
	var fallen := matriarch(row, source.treatment)
	fallen.global_transform = source.global_transform.rotated(Vector3.UP, -.27)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	var duration: float = fallen.begin_death_from(source)
	assert(duration > 0.0 and fallen.current_clip == "Death")
	var jump := 0.0
	for joint: String in ["bip01 head", "cp_grasp_lhand", "cp_grasp_rhand", "bone29", "bone15"]:
		jump = maxf(jump, landmark(source, joint).distance_to(landmark(fallen, joint)))
	assert(jump < .002, "%s handoff displaced %.6f m" % [source.current_clip, jump])
	var gap := INF
	var skins := body_skins(fallen)
	for sample in 31:
		seek(fallen, sample / 30.0)
		gap = minf(gap, minimum_gap(fallen, floor, skins))
	assert(gap >= .0018, "%s fall has gap %.6f" % [source.current_clip, gap])
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	corpse.free()
	fallen.free()
	return {"jump": jump, "gap": gap}

