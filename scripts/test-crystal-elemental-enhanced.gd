# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const CrystalFit := preload("bake-crystal-elemental-enhanced.gd")
const Body := 300
const Renderer := "res://Presentation/SourceEnhancedCrystalElementalVisual.gd"


static func source_routes() -> Dictionary:
	var clips := CrystalFit.Clips
	return {"0": {"2": [clips[15], clips[15]], "5": [clips[26], clips[27]], "8": [clips[28]],
		"11": [clips[12], clips[12], clips[12]], "14": [clips[11]], "15": [clips[23]]}, "1": {"5": [clips[26]]}}


static func fitted_row(base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = source_routes()
	row.archive_grounded_gestures = CrystalFit.Clips.values()
	row.presentation_script = Renderer
	for treatment: String in row.assets:
		row.assets[treatment] = CrystalFit.Destination + "%d-%s.scn" % [Body, treatment]
	return row


func run() -> void:
	var base := Registry.entry(Body).duplicate(true)
	base.assets = Installed.registered_assets(base)
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
		"gap": INF, "fall_gap": INF, "handoff": 0.0, "fragment_samples": 0, "fragment_falls": 0,
		"minimum_fragment_travel": INF, "hashes": {}}
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
			for clip: String in CrystalFit.Clips.values():
				start_crystal_elemental_clip(avatar, clip, packets)
				var positions := {}
				for sample in 31:
					seek(actor, sample / 30.0)
					var gap := minimum_gap(actor, floor, [actor.fitted_fall.skin])
					if clip == CrystalFit.Clips[23]:
						assert(actor.fragments.visible == (float(sample) / 30.0 < CrystalFit.CrystalJoin))
						if actor.fragments.visible:
							gap = actor.fragment_gap(floor.position, floor.basis.y)
							report.fragment_samples += 1
						if sample == 0:
							for part: MeshInstance3D in actor.fragments.get_children():
								positions[part.name] = part.global_position
						if sample == 22:
							var maximum_travel := 0.0
							for part: MeshInstance3D in actor.fragments.get_children():
								maximum_travel = maxf(maximum_travel, part.global_position.distance_to(positions[part.name]))
							assert(maximum_travel > .50)
							report.minimum_fragment_travel = minf(report.minimum_fragment_travel, maximum_travel)
					assert(gap >= .0018, "%s fell through the support plane by %.5f m" % [clip, gap])
					report.gap = minf(report.gap, gap)
					report.poses += 1
				for phase: float in [.19, .67]:
					start_crystal_elemental_clip(avatar, clip, packets)
					seek(actor, phase)
					var witness := check_fall(actor, floor, row)
					if actor.fragments.visible:
						report.fragment_falls += 1
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
	assert(report.fragment_samples == 345 and report.fragment_falls == 30)
	var receipt := FileAccess.open(CrystalFit.Destination + "runtime-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify(report, "\t"))
	receipt.close()
	print("CRYSTAL ELEMENTAL RUNTIME ", report)
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
		assert(actor.current_clip == (CrystalFit.Clips[25] if flags == 0 else "Idle"))
		actor.play_gait(true, 2.0)
		assert(actor.current_clip == "Walk")
		actor.play_gait(true, 7.0)
		assert(actor.current_clip == "Run")
	return 6


func start_crystal_elemental_clip(avatar: Avatar, clip: String, packets: Dictionary) -> void:
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
	if source.fragments.visible:
		var result := check_fragment_fall(source, fallen, floor)
		fallen.free()
		return result
	assert(fallen.begin_death_from(source) > 0.0 and fallen.current_clip == "Death")
	var jump := 0.0
	for joint: String in ["bip01 head", "box72", "bone65", "bip01 r foot"]:
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


func check_fragment_fall(source: Node3D, fallen: Node3D, floor: StaticBody3D) -> Dictionary:
	assert(fallen.begin_death_from(source) == fallen.FragmentFallTime and fallen.current_clip == fallen.FragmentFall)
	assert(fallen.fragments.visible and not fallen.body_mesh.visible)
	var jump := 0.0
	for part: MeshInstance3D in fallen.fragments.get_children():
		var previous: MeshInstance3D = source.fragments.get_node(NodePath(part.name))
		jump = maxf(jump, part.global_position.distance_to(previous.global_position))
	assert(jump < .002)
	var gap := INF
	for sample in 31:
		fallen.settle_fragment_fall(float(sample) / 30.0)
		gap = minf(gap, fallen.fragment_gap(floor.position, floor.basis.y))
	assert(gap >= .0016)
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var frozen: Node3D = snapshot.scene.instantiate()
	assert(frozen.get_child_count() == 8 and frozen.get_meta("corpse_body") == Body
		and frozen.get_meta("native_hue") == 0x8035 and frozen.get_meta("death_clip") == fallen.FragmentFall)
	assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
	if fallen.treatment == "modern":
		var latest := Corpses.build(Body, 0x489)
		assert(Snapshot.use_current_materials(frozen, latest, snapshot.hidden_props,
			snapshot.retained_prop_materials, snapshot.material_sources))
		assert(frozen.get_meta("native_hue") == 0x489 and frozen.get_child_count() == 8)
		var palette := preload("res://Presentation/HumanHue.gd").palette(0x489)
		for part: MeshInstance3D in frozen.get_children():
			var material := part.get_active_material(0) as ShaderMaterial
			assert(material != null and material.get_shader_parameter("hue_palette") == palette)
		latest.free()
	frozen.free()
	return {"handoff": jump, "gap": gap}
