# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/goat-eagle/"
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Modes := {
	209: {"0": {"2": ["GoatQuietStand", "GoatQuietStand"], "5": ["GoatLoweredHornCheck", "GoatQuietStand"],
		"8": ["GoatQuietStand"], "11": ["GoatQuietStand", "GoatQuietStand", "GoatQuietStand"],
		"14": ["GoatQuietStand"], "15": ["GoatQuietStand"]}, "1": {"5": ["GoatLoweredHornCheck"]}},
	5: {"0": {"2": ["EagleQuietWatch", "EagleQuietWatch"], "5": ["EagleGlance", "EagleQuietWatch"],
		"8": ["EagleQuietWatch"], "11": ["EagleWingBeat", "EagleWingBeat", "EagleWingBeat"],
		"14": ["EagleQuietWatch"], "15": ["EagleQuietWatch"]}, "1": {"5": ["EagleGlance"]}},
}
const Grounded := {209: ["GoatQuietStand", "GoatLoweredHornCheck"], 5: ["EagleQuietWatch", "EagleGlance"]}
var installed := false

func run() -> void:
	var bases := {209: Registry.entry(209), 5: Registry.entry(5)}
	installed = "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var report := {}
	for body: int in Modes:
		report[str(body)] = await review(game, body, bases[body])
		assert(not report[str(body)].is_empty())
	game.free()
	if not installed:
		var receipt := FileAccess.open(Stage + "goat-eagle-candidate.json", FileAccess.WRITE)
		assert(receipt != null)
		receipt.store_string(JSON.stringify({"bodies": report, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		receipt.close()
	quit()

func review(game: Node, body: int, base: Dictionary) -> Dictionary:
	var row := Registry.entry(body) if installed else base.duplicate(true)
	var modes: Dictionary = Modes[body]
	if not installed:
		row.enhanced_source_action_groups = modes
		row.archive_grounded_gestures = Grounded[body]
		if body == 5:
			row.flight_falls_back_to_combat = true
		if body == 209:
			row.presentation_script = "res://Presentation/SourceEnhancedFieldVisual.gd"
		for treatment: String in row.assets:
			row.assets[treatment] = Stage + "%d-%s.scn" % [body, treatment]
		Registry.entries[body] = row
	assert(row.enhanced_source_action_groups == modes)
	game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
	var counts := Vector2i.ZERO
	var samples := 0
	var gaps := {}
	var geometry := {}
	var hashes := {}
	var handoffs := []
	var flight_checks := 0
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var visual := create_actor(body, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = visual
			if tilt == Vector3.ZERO:
				Bake.verify_base_clips(visual.animator, Registry.asset_path(base, treatment))
				counts += check_routes(avatar, game, body, modes)
				hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
			if body == 209:
				for kind: int in [5, 14]:
					var clip: String = modes["0"][str(kind)][0]
					var gap := sample(avatar, floor, decode(game, body, kind, 0), clip)
					gaps[clip] = minf(gap, gaps.get(clip, INF))
					samples += 31
				if tilt == Vector3.ZERO and treatment == "modern":
					geometry["horn_drop"] = goat_horn_drop(visual)
			else:
				for spec: Array in [[5, false], [14, false], [11, false], [11, true]]:
					var clip: String = modes["0"][str(spec[0])][0]
					var display := "Air" + clip if spec[1] else clip
					var result := sample_eagle(avatar, floor, decode(game, body, spec[0], 0), clip, spec[1])
					gaps[display] = minf(result.gap, gaps.get(display, INF))
					if tilt == Vector3.ZERO:
						geometry[display] = result
					samples += 31
				check_queued_landing(avatar, decode(game, 5, 5, 0))
				flight_checks += check_eagle_flight_mode(avatar, decode(game, 5, 5, 1))
				for mode: String in ["ground", "air", "explicit_air", "hopping"]:
					handoffs.append(check_eagle_fall(avatar, floor, decode(game, 5, 11, 0), mode))
			avatar.free()
			visual.free()
		floor.free()
		await physics_frame
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(body, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("corpse_body") == body)
		assert(corpse.get_meta("graphic_id") == 0x2006 and corpse.get_meta("native_hue") == hue)
		assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
	Registry.entries[body] = base
	assert(counts == (Vector2i(144, 108) if body == 209 else Vector2i(48, 36)))
	assert(samples == (930 if body == 209 else 620))
	assert(handoffs.size() == (0 if body == 209 else 20))
	assert(flight_checks == (0 if body == 209 else 15))
	print("GOAT AND EAGLE ", body, ": ", counts, " ", samples, " slope poses, ", gaps, " ", geometry)
	if not handoffs.is_empty():
		print("EAGLE DEATH: ", handoffs.size(), " witnessed world-visual handoffs, max pose jump ", handoffs.map(func(row: Dictionary): return row.jump).max())
	return {"routes": counts.x, "classic_comparisons": counts.y, "terrain_poses": samples, "gaps": gaps,
		"geometry": geometry, "corpse_hues": 3, "scene_sha256": hashes, "handoffs": handoffs,
		"flight_fallback_checks": flight_checks}

func create_actor(body: int, treatment: String = "modern") -> Node3D:
	var visual: Node3D
	if body == 5 and not installed:
		visual = load(Stage + "EagleVisual.gd").new()
		visual.entry = Registry.entry(body)
	else:
		visual = Registry.create(body)
	visual.treatment = treatment
	root.add_child(visual)
	visual.apply_identity(body, 0x8035)
	visual.set_process(false)
	visual.set_physics_process(false)
	visual.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return visual

func goat_horn_drop(visual: Node3D) -> float:
	var rig: Skeleton3D = visual.skeleton
	var head := rig.find_bone("bip01 head")
	visual.play("Idle", 0.0)
	visual.animator.advance(0.0)
	rig.force_update_all_bone_transforms()
	var idle := rig.to_global(rig.get_bone_global_pose(head).origin).y
	visual.play("GoatLoweredHornCheck", 0.0)
	visual.animator.seek(.55, true)
	rig.force_update_all_bone_transforms()
	var drop := idle - rig.to_global(rig.get_bone_global_pose(head).origin).y
	assert(drop > .15, "Goat head drop %f" % drop)
	return drop

func prepare_eagle(visual: Node3D, airborne: bool) -> void:
	visual.dead = false
	visual.action_remaining = 0.0
	visual.transition_remaining = 0.0
	visual.pending_ground_clip = ""
	visual.flight_state = "ground"
	visual.current_clip = "Idle"
	visual.contact.enabled = true
	visual.fall.plane = {}
	visual.animator.stop()
	visual.play("Idle", 0.0)
	visual.animator.advance(0.0)
	if airborne:
		visual.play_gait(true, 1.8)
		assert(visual.current_clip == "TakeOff")
		visual.animator.advance(.13)
		visual.animator.seek(visual.animator.current_animation_length, true)
		visual._process(visual.transition_remaining + .01)
		visual.animator.advance(.13)
		assert(visual.flight_state == "air")

func sample_eagle(avatar: Avatar, floor: StaticBody3D, packet: Dictionary, clip: String, airborne: bool) -> Dictionary:
	var visual := avatar.horse_visual
	prepare_eagle(visual, airborne)
	assert(Dispatch.dispatch(avatar, packet, true, 64) and visual.current_clip == clip)
	var assigned := "Air" + clip if airborne else clip
	assert(visual.animator.assigned_animation == assigned)
	visual.animator.advance(.13)
	var result := {"gap": INF, "lowest_beak": INF, "maximum_span": 0.0, "maximum_wing": -INF, "minimum_wing": INF}
	var rig: Skeleton3D = visual.skeleton
	var skin := skin_for(visual)
	var fixed: Transform3D = visual.global_transform
	for i in 31:
		visual.animator.seek(visual.animator.current_animation_length * i / 30.0, true)
		for step in 36:
			visual._physics_process(1.0 / 60.0)
		rig.force_update_all_bone_transforms()
		result.gap = minf(result.gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, floor.position, floor.basis.y))
		var torso := rig.get_bone_global_pose(0).origin
		var left := rig.get_bone_global_pose(11).origin
		var right := rig.get_bone_global_pose(15).origin
		var beak := rig.get_bone_global_pose(3).origin
		var wing := rig.global_basis * ((left + right) * .5 - torso)
		result.maximum_wing = maxf(result.maximum_wing, wing.y)
		result.minimum_wing = minf(result.minimum_wing, wing.y)
		result.maximum_span = maxf(result.maximum_span, (rig.global_basis * (left - right)).length())
		result.lowest_beak = minf(result.lowest_beak, (rig.global_basis * (beak - torso)).y)
	assert(visual.global_transform.is_equal_approx(fixed) and not visual.contact.contacts.is_empty())
	assert(result.gap > (.12 if airborne else -.008), "%s skin gap %f on %s" % [assigned, result.gap, floor.rotation])
	if airborne:
		assert(result.maximum_wing - result.minimum_wing > .60 and result.lowest_beak < -.11, str(result))
	return result

func check_queued_landing(avatar: Avatar, packet: Dictionary) -> void:
	var visual := avatar.horse_visual
	prepare_eagle(visual, true)
	assert(Dispatch.dispatch(avatar, packet, true, 64))
	assert(visual.flight_state == "landing_action" and visual.pending_ground_clip == "EagleGlance")
	assert(visual.animator.assigned_animation == "Land")
	visual._process(visual.transition_remaining + .001)
	assert(visual.flight_state == "ground" and visual.animator.assigned_animation == "EagleGlance")
	assert(visual.action_remaining > 0.0)

func check_eagle_flight_mode(avatar: Avatar, packet: Dictionary) -> int:
	var visual := avatar.horse_visual
	for flags: int in [0, 4, 68]:
		prepare_eagle(visual, false)
		assert(Dispatch.dispatch(avatar, packet, true, flags))
		assert(visual.current_clip == ("EagleGlance" if flags == 0 else "EagleQuietWatch"))
	return 3

func check_eagle_fall(avatar: Avatar, floor: StaticBody3D, packet: Dictionary, mode: String) -> Dictionary:
	var source := avatar.horse_visual
	prepare_eagle(source, mode in ["air", "explicit_air"])
	if mode in ["air", "hopping"]:
		assert(Dispatch.dispatch(avatar, packet, true, 64))
		source.animator.advance(.13)
		source.animator.seek(.55, true)
	elif mode == "explicit_air":
		assert(source.receive_action({"protocol": "classic", "action": 8}))
		assert(source.animator.assigned_animation == "AirDeath")
		source.animator.advance(.13)
		source.animator.seek(.24, true)
	source.skeleton.force_update_all_bone_transforms()
	var pre_pose: Vector3 = source.skeleton.to_global(source.skeleton.get_bone_global_pose(3).origin)
	var fallen := create_actor(5)
	fallen.global_transform = source.global_transform
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	var duration: float = fallen.begin_death_from(source)
	var expected := "Death" if mode == "ground" else "AirDeath"
	assert(fallen.animator.assigned_animation == expected and duration > 0.0)
	fallen.skeleton.force_update_all_bone_transforms()
	var pose: Vector3 = fallen.skeleton.to_global(fallen.skeleton.get_bone_global_pose(3).origin)
	var jump := pose.distance_to(pre_pose)
	assert(jump < (.10 if mode == "ground" else .012), "%s head jump %f" % [mode, jump])
	var skin := skin_for(fallen)
	var minimum := INF
	var first: float = fallen.animator.current_animation_position
	for index in 31:
		fallen.animator.seek(lerpf(first, fallen.animator.current_animation_length, index / 30.0), true)
		fallen.skeleton.force_update_all_bone_transforms()
		minimum = minf(minimum, Ground.minimum_plane_gap(skin, fallen.skeleton, fallen.skeleton.global_transform, floor.position, floor.basis.y))
	assert(minimum > -.003, "%s death gap %f" % [mode, minimum])
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty() and snapshot.body == 5)
	var frozen: Node3D = snapshot.scene.instantiate()
	assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty() and frozen.get_meta("native_hue") == 0x8035)
	frozen.free()
	fallen.free()
	return {"case": mode, "clip": expected, "jump": jump, "minimum_gap": minimum}

func skin_for(visual: Node3D) -> Dictionary:
	var mesh: MeshInstance3D = visual.model.find_children("*", "MeshInstance3D", true, false)[0]
	return Ground.skin_points(mesh, visual.skeleton)
