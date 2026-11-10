# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Ice := preload("bake-ice-elemental-enhanced.gd")
const Terathan := preload("bake-terathan-drone-warrior-enhanced.gd")


static func family_modes(body: int) -> Dictionary:
	if body == 161:
		return {"0": {"8": [Ice.Clips[28]], "15": [Ice.Clips[23]]}, "1": {}}
	var idle := Terathan.clip_name(body, 1)
	var cast := Terathan.clip_name(body, 12)
	return {"0": {"5": [idle, Terathan.clip_name(body, 27)], "8": [Terathan.clip_name(body, 28)],
		"11": [cast, cast, cast], "15": [Terathan.clip_name(body, 23)]}, "1": {"5": [idle]}}


static func family_row(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	var folder := Ice.Destination if body == 161 else Terathan.Destination
	for treatment: String in row.assets:
		row.assets[treatment] = folder + "%d-%s.scn" % [body, treatment]
	row.enhanced_source_action_groups = family_modes(body)
	var clips: Array = []
	for choices: Array in row.enhanced_source_action_groups["0"].values():
		for name: String in choices:
			if name not in clips:
				clips.append(name)
	row.archive_grounded_gestures = clips
	return row


func actor_for(body: int, row: Dictionary, treatment: String) -> Node3D:
	if Installed.enabled:
		return super.actor_for(body, row, treatment)
	var path := Ice.Destination + "SourceEnhancedIceElementalVisual.gd" if body == 161 else Terathan.Destination + "SourceEnhancedTerathanVisual.gd"
	var script := load(path) as GDScript
	var actor: Node3D = script.new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func run() -> void:
	var installed := "--installed" in OS.get_cmdline_user_args()
	var bases := {}
	for body: int in [161, 71, 70]:
		bases[body] = Registry.entry(body)
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var result := {}
	for body: int in [161, 71, 70]:
		var base: Dictionary = bases[body]
		var row := Registry.entry(body) if installed else family_row(body, base)
		var modes: Dictionary = row.enhanced_source_action_groups
		assert(modes == family_modes(body))
		var clips := {}
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		for kind: String in modes["0"]:
			var choices: Array = modes["0"][kind]
			for variation in choices.size():
				if not clips.has(choices[variation]):
					clips[choices[variation]] = decode(game, body, int(kind), variation)
		var proof := await review_family(game, body, row, base, clips)
		assert(proof.poses == 465 * clips.size() and proof.falls == 30 * clips.size())
		result[str(body)] = proof
	game.free()
	if not installed:
		var file := FileAccess.open(Terathan.Destination + "terrain-receipt.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"bodies": result, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	quit()


func review_family(game: Node, body: int, row: Dictionary, base: Dictionary, clips: Dictionary) -> Dictionary:
	var proof := {"poses": 0, "falls": 0, "gap": INF, "fall_gap": INF, "jump": 0.0, "routes": 0, "classic": 0, "hashes": {},
		"retained_falls": 0}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := actor_for(body, row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			var skins := body_skins(actor)
			if tilt == Vector3.ZERO:
				if body == 161:
					Ice.verify_body_keys(actor.animator, Registry.asset_path(base, treatment))
				else:
					Giants.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
				var count := check_routes(avatar, game, body, row.enhanced_source_action_groups)
				proof.routes += count.x
				proof.classic += count.y
				proof.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
			for clip: String in clips:
				start_action(avatar, clips[clip], clip)
				for sample in 31:
					seek(actor, sample / 30.0)
					var gap := minimum_gap(actor, floor, skins)
					assert(gap >= .0018, "%d %s %.2f floor %.7f" % [body, clip, sample / 30.0, gap])
					proof.gap = minf(proof.gap, gap)
					proof.poses += 1
				for phase: float in [.17, .62]:
					start_action(avatar, clips[clip], clip)
					seek(actor, phase)
					var fall := check_giant_fall(actor, floor, body, row)
					proof.jump = maxf(proof.jump, fall.jump)
					proof.fall_gap = minf(proof.fall_gap, fall.gap)
					proof.falls += 1
			if body == 161:
				proof.retained_falls += check_retained_falls(actor, avatar, floor, skins)
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	print("ICE AND TERATHAN RUNTIME ", body, " ", proof)
	return proof


func check_retained_falls(actor: Node3D, avatar: Avatar, floor: StaticBody3D, skins: Array[Dictionary]) -> int:
	for action: int in [2, 3]:
		actor.dead = false
		var packet := {"protocol": "classic", "body": 161, "serial": 161, "action": action,
			"frames": 9, "repeat_count": 1, "delay": 0, "repeat": false, "reverse": false}
		assert(Classic.dispatch(avatar, packet) and actor.current_clip == ("Death" if action == 2 else "Death2"))
		actor.animator.advance(.18)
		for sample in 31:
			seek(actor, sample / 30.0)
			assert(minimum_gap(actor, floor, skins) >= .0018)
		var snapshot := Snapshot.capture(actor, actor.corpse_snapshot_floor())
		var corpse: Node3D = snapshot.scene.instantiate()
		assert(corpse.has_node("IceCrystalShell") and corpse.get_meta("native_hue") == 0x8035)
		corpse.free()
	return 2
