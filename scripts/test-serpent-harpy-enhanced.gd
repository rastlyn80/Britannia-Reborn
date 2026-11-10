# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/serpent-harpy/"
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const SkinGeometry := preload("res://Presentation/SkinGeometry.gd")
var fitted_installed := false
const Modes := {
	21: {"0": {"5": ["SerpentLowWatch", "SerpentRaisedCoil"], "8": ["SerpentCoilAlert"],
		"11": ["SerpentUncoilStrike", "SerpentUncoilStrike", "SerpentUncoilStrike"], "15": ["SerpentSurface"]},
		"1": {"5": ["SerpentLowWatch"]}},
	30: {"0": {"5": ["HarpyFoldedGlance", "HarpyBank"], "8": ["HarpySpreadAlert"],
		"11": ["HarpyDoubleWingbeat", "HarpyDoubleWingbeat", "HarpyDoubleWingbeat"], "15": ["HarpyGlideSettle"]},
		"1": {"5": ["HarpyFoldedGlance"]}},
}

func run() -> void:
	var bases := {21: Registry.entry(21), 30: Registry.entry(30)}
	fitted_installed = "--installed" in OS.get_cmdline_user_args()
	if fitted_installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var results := {}
	for body: int in Modes:
		results[str(body)] = await review(game, body, bases[body])
		assert(results[str(body)].has("selection"))
	game.free()
	if not fitted_installed:
		var receipt := FileAccess.open(Stage + "integration/terrain-receipt.json", FileAccess.WRITE)
		assert(receipt != null)
		var evidence := {"bodies": results, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}
		receipt.store_string(JSON.stringify(evidence, "\t"))
		receipt.close()
	quit()

func review(game: Node, body: int, base: Dictionary) -> Dictionary:
	var row := Registry.entry(body) if fitted_installed else base.duplicate(true)
	var modes: Dictionary = Modes[body]
	if not fitted_installed:
		row.enhanced_source_action_groups = modes
		row.archive_grounded_gestures = ["HarpyFoldedGlance", "HarpySpreadAlert"] if body == 30 else [
			"SerpentLowWatch", "SerpentRaisedCoil", "SerpentCoilAlert", "SerpentUncoilStrike", "SerpentSurface"]
		if body == 30:
			row.flight_falls_back_to_combat = true
		for treatment: String in row.assets:
			row.assets[treatment] = Stage + "%d-%s.scn" % [body, treatment]
		Registry.entries[body] = row
	game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
	var positions := {"5:0": [5, 0], "5:1": [5, 1], "8": [8, 0], "11": [11, 0], "15": [15, 0]}
	var report := {"selection": 0, "classic": 0, "poses": 0, "hashes": {}, "gaps": {}, "handoffs": [], "flight_flag_checks": 0, "geometry": {}}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := create_fit(body, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				Bake.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
				var counts := check_routes(avatar, game, body, modes)
				report.selection += counts.x
				report.classic += counts.y
				report.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				if body == 30:
					report.flight_flag_checks += check_flight_flags(avatar, game, body)
			for choice: Array in positions.values():
				var packet := decode(game, body, choice[0], choice[1])
				var expected: String = modes["0"][str(choice[0])][choice[1]]
				var data := sample_fit(avatar, floor, packet, expected, body)
				report.gaps[expected] = minf(data.gap, report.gaps.get(expected, INF))
				report.poses += 31
				if tilt == Vector3.ZERO and treatment == "modern":
					report.geometry[expected] = data
			if body == 30:
				for kind: int in [11, 15]:
					report.handoffs.append(handoff(avatar, floor, decode(game, body, kind, 0), treatment))
			else:
				for phase: float in [.05, .35, .7, .96]:
					report.handoffs.append(surface_handoff(avatar, floor, decode(game, body, 15, 0), treatment, phase))
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(body, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("corpse_body") == body)
		assert(corpse.get_meta("graphic_id") == 0x2006 and corpse.get_meta("native_hue") == hue)
		assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
	Registry.entries[body] = base
	assert(report.selection == 96 and report.classic == 72 and report.poses == 2325)
	assert(report.handoffs.size() == (30 if body == 30 else 60))
	assert(report.flight_flag_checks == (9 if body == 30 else 0))
	assert(report.handoffs.all(func(row: Dictionary): return row.has("jump")))
	print("SERPENT/HARPY ", body, " selections ", report.selection, ", poses ", report.poses, ", gaps ", report.gaps, ", geometry ", report.geometry)
	return report

func create_fit(body: int, treatment: String) -> Node3D:
	var visual: Node3D
	if fitted_installed:
		visual = Registry.create(body)
	else:
		var renderer := "SourceEnhancedHarpyVisual.gd" if body == 30 else "SourceEnhancedSerpentVisual.gd"
		visual = load(Stage + "integration/" + renderer).new()
	visual.entry = Registry.entry(body)
	visual.treatment = treatment
	root.add_child(visual)
	visual.apply_identity(body, 0x8035)
	visual.set_process(false)
	visual.set_physics_process(false)
	visual.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return visual

func sample_fit(avatar: Avatar, floor: StaticBody3D, packet: Dictionary, clip: String, body: int) -> Dictionary:
	var visual := avatar.horse_visual
	var player: AnimationPlayer = visual.animator
	var rig: Skeleton3D = visual.skeleton
	var mesh: MeshInstance3D = visual.model.find_children("*", "MeshInstance3D", true, false)[0]
	var skin := Ground.skin_points(mesh, rig)
	var anchor: Transform3D = visual.global_transform
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	assert(Dispatch.dispatch(avatar, packet, true, 0x40) and visual.current_clip == clip)
	player.advance(.13)
	var result := {"gap": INF, "start_top": 0.0, "end_top": 0.0, "end_gap": 0.0, "spread": 0.0, "lift": 0.0, "reach": 0.0}
	var front := rig.find_bone("bip01 head")
	var pelvis := rig.find_bone("bip01 pelvis")
	var left := rig.find_bone("bip01 l hand")
	var right := rig.find_bone("bip01 r hand")
	var initial := Vector3.ZERO
	for i in 31:
		player.seek(player.current_animation_length * i / 30.0, true)
		for step in 14:
			visual._physics_process(1.0 / 60.0)
		if body == 30 and visual.contact.enabled:
			visual.contact._process_modification_with_delta(1.0 / 60.0)
			visual.contact.modification_processed.emit()
		rig.force_update_all_bone_transforms()
		var current := Ground.minimum_plane_gap(skin, rig, rig.global_transform, floor.position, floor.basis.y)
		result.gap = minf(result.gap, current)
		result.end_gap = current
		var torso := rig.to_global(rig.get_bone_global_pose(pelvis).origin)
		var head := rig.to_global(rig.get_bone_global_pose(front).origin)
		result.lift = maxf(result.lift, floor.basis.y.dot(torso - floor.position))
		if i == 0:
			initial = head
		result.reach = maxf(result.reach, (head - initial).slide(floor.basis.y).length())
		if left >= 0:
			var difference := rig.get_bone_global_pose(left).origin - rig.get_bone_global_pose(right).origin
			result.spread = maxf(result.spread, (rig.global_basis * difference).length())
		if clip == "SerpentSurface" and i in [0, 30]:
			result["start_top" if i == 0 else "end_top"] = SkinGeometry.deformed_bounds(mesh, rig).end.y
	assert(visual.global_transform.is_equal_approx(anchor))
	if clip == "SerpentSurface":
		assert(result.start_top < .08 and result.end_top > .25 and result.end_gap > -.003, str(result))
	else:
		assert(result.gap > -.004, "%s %s %s" % [clip, floor.rotation, str(result)])
	return result

func handoff(avatar: Avatar, floor: StaticBody3D, packet: Dictionary, treatment: String) -> Dictionary:
	var source := avatar.horse_visual
	assert(Dispatch.dispatch(avatar, packet, true, 0x40))
	source.animator.advance(.13)
	source.animator.seek(.55, true)
	source.skeleton.force_update_all_bone_transforms()
	var head := int(source.skeleton.find_bone("bip01 head"))
	var before: Vector3 = source.skeleton.to_global(source.skeleton.get_bone_global_pose(head).origin)
	var fallen := create_fit(30, treatment)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	var duration: float = fallen.begin_death_from(source)
	assert(duration > 0.0 and fallen.current_clip == "AirDeath")
	var rig: Skeleton3D = fallen.skeleton
	rig.force_update_all_bone_transforms()
	var jump := before.distance_to(rig.to_global(rig.get_bone_global_pose(head).origin))
	if jump >= .02:
		print("HARPY FALL DIAGNOSTIC ", source.current_clip, " ", floor.rotation, " ", before, " -> ",
			rig.to_global(rig.get_bone_global_pose(head).origin), ", support ", fallen.fitted_fall.plane.get("normal"),
			", shift ", fallen.fitted_fall.shift, ", blend ", fallen.fitted_fall.blend_pose.size(),
			", source/fall skeleton position ", source.skeleton.global_position, " / ", rig.global_position)
	assert(jump < .02, "Harpy fall head jump %f" % jump)
	var mesh: MeshInstance3D = fallen.model.find_children("*", "MeshInstance3D", true, false)[0]
	var skin := Ground.skin_points(mesh, rig)
	var gap := INF
	for i in 31:
		fallen.animator.seek(fallen.animator.current_animation_length * i / 30.0, true)
		rig.force_update_all_bone_transforms()
		gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, floor.position, floor.basis.y))
	assert(gap > -.004, "Harpy fall gap %f" % gap)
	var frozen := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not frozen.is_empty() and frozen.body == 30)
	fallen.free()
	return {"kind": packet.type, "jump": jump, "gap": gap}


func check_flight_flags(avatar: Avatar, game: Node, body: int) -> int:
	var packet := decode(game, body, 5, 1)
	for flags: int in [0, 4, 68]:
		assert(Dispatch.dispatch(avatar, packet, true, flags))
		assert(avatar.horse_visual.current_clip == ("HarpyFoldedGlance" if flags == 0 else "HarpyBank"))
	return 3

func surface_handoff(avatar: Avatar, floor: StaticBody3D, packet: Dictionary, treatment: String, phase: float) -> Dictionary:
	var source := avatar.horse_visual
	source.animator.stop()
	assert(Dispatch.dispatch(avatar, packet, true, 0x40) and source.current_clip == "SerpentSurface")
	source.animator.advance(.13)
	source.animator.seek(source.animator.current_animation_length * phase, true)
	source._physics_process(1.0 / 60.0)
	source.skeleton.force_update_all_bone_transforms()
	var head := int(source.skeleton.find_bone("bip01 head"))
	var before: Vector3 = source.skeleton.to_global(source.skeleton.get_bone_global_pose(head).origin)
	var source_mesh: MeshInstance3D = source.model.find_children("*", "MeshInstance3D", true, false)[0]
	var source_gap := Ground.minimum_plane_gap(Ground.skin_points(source_mesh, source.skeleton), source.skeleton,
		source.skeleton.global_transform, floor.position, floor.basis.y)
	var fallen := create_fit(21, treatment)
	fallen.global_transform = source.global_transform
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	var duration: float = fallen.begin_death_from(source)
	assert(duration > .24 and fallen.current_clip == "Death")
	var rig: Skeleton3D = fallen.skeleton
	rig.force_update_all_bone_transforms()
	var jump := before.distance_to(rig.to_global(rig.get_bone_global_pose(head).origin))
	assert(jump < .002, "Serpent rise fall at %s on %s, jump %f" % [phase, floor.rotation, jump])
	var mesh: MeshInstance3D = fallen.model.find_children("*", "MeshInstance3D", true, false)[0]
	var skin := Ground.skin_points(mesh, rig)
	var recovered_gap := INF
	for i in 31:
		var time := duration * i / 30.0
		fallen.animator.seek(time, true)
		rig.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, floor.position, floor.basis.y)
		if i == 0:
			assert(absf(source_gap - gap) < .002)
		if time >= .24:
			recovered_gap = minf(recovered_gap, gap)
	assert(recovered_gap > -.003, "Serpent fall must surface before landing: %f" % recovered_gap)
	var frozen := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not frozen.is_empty() and frozen.body == 21)
	var corpse: Node3D = frozen.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035)
	corpse.free()
	fallen.free()
	return {"phase": phase, "jump": jump, "start_gap": source_gap, "gap": recovered_gap}
