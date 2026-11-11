# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Fit := preload("bake-crystal-lattice-seeker-enhanced.gd")
const VisualPath := "res://Presentation/SourceEnhancedLatticeSeekerVisual.gd"
const EventPath := "res://Presentation/SourceEnhancedLatticeEventPresenter.gd"
const Lattice := preload(VisualPath)
const AttackDispatch := preload("res://Presentation/EnhancedCreatureAttackActions.gd")
const Landmarks := ["bip01 head", "bip01 r hand", "box04", "box07"]
const Body := 123


static func source_routes() -> Dictionary:
	var clips := Fit.Clips
	return {"0": {"2": [clips[15], clips[15]], "3": ["Death", "Death2"], "4": [clips[10]],
		"5": [clips[26], clips[27]], "8": [clips[28]], "11": [clips[12], clips[12], clips[12]],
		"14": [clips[11]], "15": [clips[23]]}, "1": {"5": [clips[26]]}}


static func source_attacks() -> Dictionary:
	var a: String = Fit.Clips[4]
	var b: String = Fit.Clips[5]
	return {"0": [a, b, a], "1": [a], "2": [a], "9": [a], "255": [a, b, a, a, a, a]}


static func staged_row(base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.archive_grounded_gestures.append_array(Fit.Clips.values() + [Fit.PeaceWalk])
	row.enhanced_source_action_groups = source_routes()
	row.enhanced_attack_subactions = source_attacks()
	row.presentation_script = VisualPath
	for treatment: String in row.assets:
		row.assets[treatment] = Fit.Destination + "%d-%s.scn" % [Body, treatment]
	return row


func run() -> void:
	var base := Registry.entry(Body)
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	var row := Registry.entry(Body) if installed else staged_row(base)
	assert(row.enhanced_source_action_groups == source_routes() and row.enhanced_attack_subactions == source_attacks())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[Body] = {"serial": Body, "body": Body, "hue": 0x47e}
	var report := {"checks": 0, "poses": 0, "falls": 0, "fall_poses": 0, "gap": INF,
		"fall_gap": INF, "jump": 0.0, "hashes": {}, "renderer_sha256": FileAccess.get_sha256(VisualPath),
		"event_sha256": FileAccess.get_sha256(EventPath)}
	var modes := source_routes()
	var cases := {"LatticeRisingStrike": packet(game, 0, 0, 0), "LatticeCrossingStrike": packet(game, 0, 0, 1)}
	for kind: String in modes["0"]:
		var clips: Array = modes["0"][kind]
		for variation in clips.size():
			var clip: String = clips[variation]
			if not cases.has(clip):
				cases[clip] = packet(game, int(kind), 0, variation)
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := make_lattice(row, treatment)
			var skins: Array[Dictionary] = visible_skins(actor)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				Fit.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
				report.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				report.checks += compare_routes(game, avatar)
			for clip: String in cases:
				start_preview(avatar, cases[clip], clip)
				for step in 17:
					sample_actor(actor, step / 16.0)
					var clearance := minimum_gap(actor, floor, skins)
					assert(clearance >= -.0001, "%s %.3f %s floor clearance %.6f" % [clip, step / 16.0, treatment, clearance])
					report.poses += 1
					report.gap = minf(report.gap, clearance)
				for phase: float in [.23, .62]:
					start_preview(avatar, cases[clip], clip)
					sample_actor(actor, phase)
					check_handoff(actor, row, floor, report)
			for gait in ["LatticePeaceWalk", "LatticeQuietHover"]:
				actor.dead = false
				actor.action_remaining = 0.0
				actor.set_native_combat_flags(0)
				actor.play_gait(gait == "LatticePeaceWalk", 1.8 if gait == "LatticePeaceWalk" else 0.0)
				actor.animator.advance(.20)
				assert(actor.current_clip == gait and actor.contact.enabled)
				for step in 17:
					sample_actor(actor, step / 16.0)
					var clearance := minimum_gap(actor, floor, skins)
					assert(clearance >= -.0001, "%s %.3f %s floor clearance %.6f" % [gait, step / 16.0, treatment, clearance])
					report.poses += 1
					report.gap = minf(report.gap, clearance)
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	game.free()
	if not installed:
		var receipt := FileAccess.open(Fit.Destination + "terrain-receipt.json", FileAccess.WRITE)
		assert(receipt != null)
		receipt.store_string(JSON.stringify(report, "\t"))
		receipt.close()
	print("LATTICE TERRAIN ", report)
	quit()


func make_lattice(row: Dictionary, treatment: String) -> Node3D:
	var actor := Lattice.new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(Body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func visible_skins(actor: Node3D) -> Array[Dictionary]:
	var skins: Array[Dictionary] = []
	for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		if mesh.is_visible_in_tree():
			skins.append(Ground.skin_points(mesh, actor.skeleton))
	assert(not skins.is_empty())
	return skins


func compare_routes(game: Node, avatar: Avatar) -> int:
	var actor: Node3D = avatar.horse_visual
	var total := 0
	var routes := source_routes()
	var attacks := source_attacks()
	for flags: int in [0, 64]:
		actor.set_native_combat_flags(flags)
		for kind: String in routes["0"]:
			for variant in [0, 1, 2, 5, 127]:
				actor.dead = false
				var choices: Array = routes["1" if flags == 0 else "0"].get(kind, routes["0"][kind])
				assert(AttackDispatch.dispatch(avatar, packet(game, int(kind), 0, variant), true, flags))
				assert(actor.current_clip == choices[variant % choices.size()])
				total += 1
		for subaction in [0, 1, 2, 9, 37, 0x100, 0x101, 0x1ff]:
			for variant in [0, 1, 2, 5, 127]:
				actor.dead = false
				var choices: Array = attacks.get(str(subaction & 255), attacks["255"])
				assert(AttackDispatch.dispatch(avatar, packet(game, 0, subaction, variant), true, flags))
				assert(actor.current_clip == choices[variant % choices.size()])
				total += 1
		actor.dead = false
		actor.action_remaining = 0.0
		actor.play_gait(true, 1.8)
		assert(actor.current_clip == ("LatticePeaceWalk" if flags == 0 else "Walk"))
		actor.play_gait(true, 5.5)
		assert(actor.current_clip == "Run")
		total += 2
	return total


func start_preview(avatar: Avatar, action: Dictionary, expected: String) -> void:
	var actor: Node3D = avatar.horse_visual
	actor.dead = false
	actor.action_remaining = 0.0
	actor.set_native_combat_flags(64)
	actor.play_gait(false, 0.0)
	actor.animator.advance(.18)
	assert(AttackDispatch.dispatch(avatar, action, true, 64) and actor.current_clip == expected)
	actor.animator.advance(.16)


func sample_actor(actor: Node3D, phase: float) -> void:
	seek(actor, phase)
	actor._physics_process(0.0)
	actor.contact.modification_processed.emit()
	actor.skeleton.force_update_all_bone_transforms()


func check_handoff(source: Node3D, row: Dictionary, floor: StaticBody3D, report: Dictionary) -> void:
	var fallen := make_lattice(row, source.treatment)
	fallen.global_transform = source.global_transform
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	var length: float = fallen.begin_death_from(source)
	assert(length > 0.0 and fallen.current_clip == ("Death2" if source.current_clip == "Death2" else "Death"))
	var gap := 0.0
	for joint: String in Landmarks:
		gap = maxf(gap, landmark(source, joint).distance_to(landmark(fallen, joint)))
	assert(gap < .0025, "Displayed %s fall moved a joint by %.6f" % [source.current_clip, gap])
	report.jump = maxf(report.jump, gap)
	var skins: Array[Dictionary] = visible_skins(fallen)
	var start: float = fallen.animator.current_animation_position
	for step in range(1, 13):
		fallen.animator.seek(lerpf(start, fallen.animator.current_animation_length, step / 12.0), true)
		fallen.skeleton.force_update_all_bone_transforms()
		var clearance := minimum_gap(fallen, floor, skins)
		assert(clearance >= -.0001, "Frozen %s terrain gap %.6f" % [fallen.current_clip, clearance])
		report.fall_gap = minf(report.fall_gap, clearance)
		report.fall_poses += 1
	assert(not is_instance_valid(fallen.arc) or not fallen.arc.visible)
	report.falls += 1
	fallen.free()


static func packet(game: Node, kind: int, subaction: int, variation: int) -> Dictionary:
	var raw := PackedByteArray([0xe2])
	raw.append_array(Wire.uint_be(Body, 4))
	raw.append_array(Wire.uint_be(kind, 2))
	raw.append_array(Wire.uint_be(subaction, 2))
	raw.append(variation)
	var received := [{}]
	game.mobile_action_received.connect(func(action: Dictionary): received[0] = action, CONNECT_ONE_SHOT)
	game._handle(raw)
	assert(not received[0].is_empty())
	return received[0]
