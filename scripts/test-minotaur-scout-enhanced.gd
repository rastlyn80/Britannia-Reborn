# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const ScoutFit := preload("bake-minotaur-scout-enhanced.gd")
const AttackDispatch := preload("res://Presentation/EnhancedCreatureAttackActions.gd")
const Body := 281
const AttackSubactions := [0, 1, 2, 9, 37, 0xffff, 0x101, 0x1ff]
const Renderer := "res://Presentation/SourceEnhancedMinotaurScoutVisual.gd"


static func source_routes() -> Dictionary:
	var clips := ScoutFit.Clips
	return {"0": {"2": [clips[15], clips[15]], "5": [clips[26], clips[27]], "8": [clips[28]],
		"11": [clips[4], clips[4], clips[4]], "14": [clips[11]], "15": [clips[23]]}, "1": {"5": [clips[26]]}}


static func source_attacks() -> Dictionary:
	var clips := ScoutFit.Clips
	return {"0": [clips[4], clips[5], clips[4]], "1": [clips[4]], "2": [clips[4]], "9": [clips[4]],
		"255": [clips[4], clips[5], clips[4], clips[4], clips[4], clips[4]]}


static func attack_group(subaction: int, variation: int) -> int:
	match subaction & 0xff:
		0:
			return [4, 5, 4][variation % 3]
		1, 2, 9:
			return 4
	return [4, 5, 4, 4, 4, 4][variation % 6]


static func fitted_row(base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = source_routes()
	row.enhanced_attack_subactions = source_attacks()
	row.archive_grounded_gestures = ScoutFit.Clips.values()
	row.presentation_script = Renderer
	for treatment: String in row.assets:
		row.assets[treatment] = ScoutFit.Destination + "%d-%s.scn" % [Body, treatment]
	return row


func run() -> void:
	var base := Registry.entry(Body).duplicate(true)
	base.assets = Installed.registered_assets(base)
	var row := fitted_row(base)
	if "--installed" in OS.get_cmdline_user_args():
		assert(Installed.enable())
		row = Registry.entry(Body)
		assert(row.enhanced_source_action_groups == source_routes() and row.presentation_script == Renderer)
		assert(row.enhanced_attack_subactions == source_attacks())
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
	for variation in 2:
		packets[ScoutFit.Clips[4 + variation]] = decode_attack(game, 0, variation)
	var report := {"poses": 0, "falls": 0, "routes": 0, "classic": 0, "gaits": 0, "attack_routes": 0, "attack_fallbacks": 0,
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
				var attack_counts := check_attack_routes(avatar, game)
				report.attack_routes += attack_counts.x
				report.attack_fallbacks += attack_counts.y
				report.gaits += check_gaits(actor)
				report.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
			for clip: String in ScoutFit.Clips.values():
				start_minotaur_scout_clip(avatar, clip, packets)
				for sample in 31:
					seek(actor, sample / 30.0)
					var gap := minimum_gap(actor, floor, [actor.fitted_fall.skin])
					assert(gap >= .0018, "%s fell through the support plane by %.5f m" % [clip, gap])
					report.gap = minf(report.gap, gap)
					report.poses += 1
				for phase: float in [.19, .67]:
					start_minotaur_scout_clip(avatar, clip, packets)
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
	assert(report.poses == 4185 and report.falls == 270 and report.routes == 144
		and report.classic == 108 and report.gaits == 18
		and report.attack_routes == 336 and report.attack_fallbacks == 192)
	var receipt := FileAccess.open(ScoutFit.Destination + "runtime-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify(report, "\t"))
	receipt.close()
	print("MINOTAUR SCOUT RUNTIME ", report)
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
		assert(actor.current_clip == (ScoutFit.Clips[25] if flags == 0 else "Idle"))
		actor.play_gait(true, 2.0)
		assert(actor.current_clip == "Walk")
		actor.play_gait(true, 7.0)
		assert(actor.current_clip == "Run")
	return 6


func decode_attack(game: Node, subaction: int, variation: int) -> Dictionary:
	var wire := PackedByteArray([0xe2])
	wire.append_array(Wire.uint_be(Body, 4))
	wire.append_array(PackedByteArray([0, 0]))
	wire.append_array(Wire.uint_be(subaction, 2))
	wire.append(variation)
	var received: Array[Dictionary] = []
	var observe := func(packet: Dictionary): received.append(packet)
	game.mobile_action_received.connect(observe)
	game._handle(wire)
	game.mobile_action_received.disconnect(observe)
	assert(received.size() == 1 and received[0].subaction == subaction)
	return received[0]


func check_attack_routes(avatar: Avatar, game: Node) -> Vector2i:
	var actor := avatar.horse_visual
	var entry: Dictionary = actor.entry
	var counts := Vector2i.ZERO
	for flags: int in [0, 64]:
		for subaction: int in AttackSubactions:
			for variation: int in [0, 1, 2, 3, 5, 6, 127]:
				var packet := decode_attack(game, subaction, variation)
				assert(AttackDispatch.dispatch(avatar, packet, true, flags))
				assert(actor.current_clip == ScoutFit.Clips[attack_group(subaction, variation)] and not actor.dead)
				assert(actor.entry == entry)
				counts.x += 1
			for fallback: Array in [[128, true, flags], [255, true, flags], [2, false, flags], [2, true, -1]]:
				var packet := decode_attack(game, subaction, fallback[0])
				var result := Classic.dispatch(avatar, packet)
				var prior: String = actor.current_clip
				assert(AttackDispatch.dispatch(avatar, packet, fallback[1], fallback[2]) == result)
				assert(actor.current_clip == prior and actor.entry == entry)
				counts.y += 1
	return counts


func start_minotaur_scout_clip(avatar: Avatar, clip: String, packets: Dictionary) -> void:
	var actor := avatar.horse_visual
	actor.action_remaining = 0.0
	var quiet := clip == ScoutFit.Clips[25]
	actor.set_native_combat_flags(0 if quiet else 64)
	actor.play_gait(false, 0.0)
	actor.animator.advance(.18)
	if not quiet:
		assert(AttackDispatch.dispatch(avatar, packets[clip], true, 64))
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
	for joint: String in ["bip01 head", "bip01 l hand", "bip01 spine2", "bip01 r foot"]:
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
