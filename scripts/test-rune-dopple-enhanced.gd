# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Batch := preload("bake-rune-dopple-enhanced.gd")
const Renderers := {244: "SourceEnhancedRuneBeetleVisual.gd", 777: "SourceEnhancedDopplegangerVisual.gd"}
const Bodies := [244, 777]
const Modes := {
	244: {"0": {"2": [Batch.Rune[25], Batch.Rune[1]], "5": [Batch.Rune[26], Batch.Rune[27]],
		"8": [Batch.Rune[28]], "14": [Batch.Rune[25]], "15": [Batch.Rune[25]]}, "1": {"5": [Batch.Rune[26]]}},
	777: {"0": {"5": [Batch.Dopple[26], Batch.Dopple[27]], "8": [Batch.Dopple[28]],
		"11": [Batch.Dopple[12], Batch.Dopple[12], Batch.Dopple[12]], "15": [Batch.Dopple[23]]},
		"1": {"5": [Batch.Dopple[26]]}},
}
const Cases := {244: {1: [2, 1], 25: [2, 0], 26: [5, 0], 27: [5, 1], 28: [8, 0]},
	777: {12: [11, 0], 23: [15, 0], 26: [5, 0], 27: [5, 1], 28: [8, 0]}}


static func row_for(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = Modes[body]
	row.archive_grounded_gestures = (Batch.Rune if body == 244 else Batch.Dopple).values()
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
		assert(summary.poses == 2325 and summary.falls == 150)
		assert(summary.routes == (120 if body == 244 else 96) and summary.classic == (90 if body == 244 else 72))
		assert(summary.growth == (15 if body == 777 else 0) and summary.gaits == (24 if body == 244 else 0))
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
	var clips := Batch.Rune if body == 244 else Batch.Dopple
	var report := {"poses": 0, "falls": 0, "growth": 0, "gaits": 0, "gap": INF, "fall_gap": INF, "jump": 0.0,
		"routes": 0, "classic": 0, "hashes": {}}
	for slope: Vector3 in Slopes:
		var floor := await create_floor(slope)
		for treatment: String in row.assets:
			var actor := create_actor(body, row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			var skins := visible_skin(actor)
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
				if body == 777 and group == 23:
					check_growth(avatar, floor, skins, packet, clip)
					report.growth += 1
			if body == 244 and slope == Vector3.ZERO:
				report.gaits += check_idle_modes(actor)
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	print("RUNE BEETLE AND DOPPLEGANGER RUNTIME ", body, " ", report)
	return report


func visible_skin(actor: Node3D) -> Array[Dictionary]:
	var mesh := actor.model.find_child("Body", true, false) as MeshInstance3D
	return [Ground.skin_points(mesh, actor.skeleton)]


func check_idle_modes(actor: Node3D) -> int:
	actor.action_remaining = 0.0
	for flag: int in [0, 64]:
		actor.set_native_combat_flags(flag)
		var idle := Batch.Rune[1 if flag == 64 else 25] as String
		actor.play_gait(false, 0.0)
		assert(actor.current_clip == idle)
		actor.animator.advance(.23)
		for rate: float in [1.8, 5.0]:
			actor.play_gait(true, rate)
			assert(actor.current_clip == ("Run" if rate > 3.6 else "Walk"))
			actor.animator.advance(.23)
			actor.play_gait(false, 0.0)
			assert(actor.current_clip == idle)
			actor.animator.advance(.23)
	return 8


func check_growth(avatar: Avatar, floor: StaticBody3D, skins: Array[Dictionary], packet: Dictionary, clip: String) -> void:
	var actor := avatar.horse_visual
	var root_joint: int = actor.skeleton.find_bone("__root")
	start_action(avatar, packet, clip)
	seek(actor, 0.0)
	assert(actor.skeleton.get_bone_pose_scale(root_joint).x < .065)
	seek(actor, .33)
	var previous: float = actor.skeleton.get_bone_pose_scale(root_joint).x
	assert(previous > .20 and previous < .90 and actor.veil.visible and actor.seal.visible)
	assert(Classic.dispatch(avatar, {"protocol": "classic", "body": 777, "action": 4}))
	actor.animator.advance(.14)
	assert(actor.current_clip == "Attack" and actor.growth.active and not actor.veil.visible and not actor.seal.visible)
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
	var joints := ["bip01 head", "bone01", "bip01 l hand"] if body == 244 else [
		"bip01 head", "bip01 l hand", "bip01 r foot"]
	var jump := 0.0
	for joint: String in joints:
		jump = maxf(jump, landmark(source, joint).distance_to(landmark(fallen, joint)))
	assert(jump < .002, "%d %s handoff displaced %.6f m" % [body, source.current_clip, jump])
	var gap := INF
	var skins := visible_skin(fallen)
	for sample in 31:
		seek(fallen, sample / 30.0)
		gap = minf(gap, minimum_gap(fallen, floor, skins))
	assert(gap >= .0016, "%s fall has gap %.6f" % [source.current_clip, gap])
	if body == 777:
		assert(not fallen.veil.visible and not fallen.seal.visible)
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	assert(corpse.find_child("DopplegangerVeil", true, false) == null and corpse.find_child("DopplegangerSeal", true, false) == null)
	corpse.free()
	fallen.free()
	return {"jump": jump, "gap": gap}

