# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Batch := preload("bake-orc-captain-solen-enhanced.gd")
const Renderers := {7: "SourceEnhancedOrcCaptainVisual.gd", 805: "SourceEnhancedBlackSolenWorkerVisual.gd"}


static func modes_for(body: int) -> Dictionary:
	if body == 7:
		return {"0": {"8": [Batch.Captain[28]], "15": [Batch.Captain[23]]}, "1": {}}
	return {"0": {"5": [Batch.Worker[26], Batch.Worker[27]], "8": [Batch.Worker[28]],
		"11": [Batch.Worker[12], Batch.Worker[12], Batch.Worker[12]], "15": [Batch.Worker[23]]},
		"1": {"5": [Batch.Worker[26]]}}


static func row_for(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = modes_for(body)
	row.archive_grounded_gestures = (Batch.Captain if body == 7 else Batch.Worker).values()
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
		assert(reports[str(body)].poses == (930 if body == 7 else 2325))
		assert(reports[str(body)].falls == (60 if body == 7 else 150))
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
	var report := {"poses": 0, "falls": 0, "alternate_falls": 0, "dye_checks": 0, "gap": INF, "fall_gap": INF,
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
			if body == 7:
				var axe := actor.model.find_child("OrcCaptainAxe", true, false) as MeshInstance3D
				assert(axe != null)
				var material := axe.get_active_material(0)
				actor.set_hue(0x489)
				assert(axe.get_active_material(0) == material)
				actor.set_hue(0x8035)
				report.dye_checks += 1
				start_fit(avatar, packets[Batch.Captain[28]], Batch.Captain[28])
				var death := {"protocol": "classic", "action": 3, "body": body}
				assert(Dispatch.dispatch(avatar, death, true, 64) and actor.current_clip == "Death2")
				actor.animator.advance(.16)
				seek(actor, .53)
				var result := check_batch_fall(actor, floor, body, row)
				assert(result.clip == "Death2")
				report.alternate_falls += 1
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	print("ORC CAPTAIN AND BLACK SOLEN WORKER RUNTIME ", body, " ", report)
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
	assert(duration > 0.0 and fallen.current_clip in ["Death", "Death2"])
	var jump := 0.0
	var joints := ["bip01 head", "cp_grasp_rhand", Batch.AxeBone] if body == 7 else ["bip01 head", "legbone lf2", "legbone rr2"]
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
	if body == 7:
		var axe := corpse.find_child("OrcCaptainAxe", true, false) as MeshInstance3D
		var living := fallen.model.find_child("OrcCaptainAxe", true, false) as MeshInstance3D
		assert(axe != null and axe.get_active_material(0) == living.get_active_material(0))
	var clip: String = fallen.current_clip
	corpse.free()
	fallen.free()
	return {"jump": jump, "gap": gap, "clip": clip}
