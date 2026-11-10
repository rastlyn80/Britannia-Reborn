# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const MammalBake := preload("res://../scripts/bake-hound-bear-enhanced.gd")
const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/brown-bear-cougar/"
const Modes := {
	167: {"0": {"2": ["BrownBearUprightWarning", "BrownBearUprightWarning"],
		"5": ["BrownBearScentTurn", "BrownBearRaisedGuard"], "8": ["BrownBearRearAlert"],
		"11": ["BrownBearHighSwipe", "BrownBearHighSwipe", "BrownBearHighSwipe"],
		"14": ["BrownBearQuietStand"], "15": ["BrownBearWakeAndRise"]}, "1": {"5": ["BrownBearScentTurn"]}},
	63: {"0": {"2": ["CougarLowFeint", "CougarLowFeint"],
		"5": ["CougarScentDip", "CougarTailFlick"], "8": ["CougarLoweredAlert"],
		"11": ["CougarHighPawStrike", "CougarHighPawStrike", "CougarHighPawStrike"],
		"14": ["CougarQuietStand"], "15": ["CougarUncoilAndStretch"]}, "1": {"5": ["CougarScentDip"]}},
}

func run() -> void:
	var bases := {167: Registry.entry(167), 63: Registry.entry(63)}
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var evidence := {}
	for body: int in Modes:
		var receipt := await review(game, body, bases[body], installed)
		assert(receipt.has("routes"))
		evidence[str(body)] = receipt
	game.free()
	if not installed:
		var file := FileAccess.open(Stage + "brown-bear-cougar-candidate.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"bodies": evidence, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	quit()

func review(game: Node, body: int, base: Dictionary, installed: bool) -> Dictionary:
	var modes: Dictionary = Modes[body]
	var clips := {}
	for kind: String in modes["0"]:
		var choices: Array = modes["0"][kind]
		for variant in choices.size():
			if not clips.has(choices[variant]):
				clips[choices[variant]] = [int(kind), variant]
	var row := Registry.entry(body) if installed else base.duplicate(true)
	if not installed:
		row.enhanced_source_action_groups = modes
		row.archive_grounded_gestures = clips.keys()
		row.presentation_script = "res://Presentation/SourceEnhancedFieldVisual.gd"
		for treatment: String in row.assets:
			row.assets[treatment] = Stage + "%d-%s.scn" % [body, treatment]
		Registry.entries[body] = row
	assert(row.enhanced_source_action_groups == modes)
	game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
	var counts := Vector2i.ZERO
	var poses := 0
	var gaps := {}
	var geometry := {}
	var hashes := {}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				Bake.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
				counts += check_routes(avatar, game, body, modes)
				hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				if treatment == "modern":
					geometry = measure(actor, body)
			for clip: String in clips:
				var selection: Array = clips[clip]
				var packet := decode(game, body, selection[0], selection[1])
				var gap := sample(avatar, floor, packet, clip)
				assert(gap >= .0019, "%s dips into %s on the %s skin: %f" % [clip, tilt, treatment, gap])
				gaps[clip] = minf(gap, gaps.get(clip, INF))
				poses += 31
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(body, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("native_hue") == hue)
		assert(corpse.get_meta("graphic_id") == 0x2006 and corpse.get_meta("corpse_body") == body)
		assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
	Registry.entries[body] = base
	assert(counts == Vector2i(144, 108) and poses == 3255)
	print("BROWN BEAR AND COUGAR ", body, ": ", counts, " ", poses, " terrain poses, ", geometry, " ", gaps)
	return {"routes": counts.x, "classic_comparisons": counts.y, "terrain_poses": poses,
		"gaps": gaps, "geometry": geometry, "corpse_hues": 3, "scene_sha256": hashes}

func measure(actor: Node3D, body: int) -> Dictionary:
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play("BrownBearRaisedGuard" if body == 167 else "CougarHighPawStrike", 0.0)
	player.advance(0.0)
	var probe := MammalBake.new()
	var anchor := probe.hind_midpoint(rig)
	var initial_head := probe.joint_world(rig, "bip01 head").y
	var result := {"paw_height": 0.0, "head_rise": 0.0, "hind_drift": 0.0, "paw_span": 0.0}
	for index in 81:
		player.seek(player.current_animation_length * index / 80.0, true)
		rig.force_update_all_bone_transforms()
		var left := probe.joint_world(rig, "bip01 l hand")
		var right := probe.joint_world(rig, "bip01 r hand")
		result.paw_height = maxf(result.paw_height, (left.y + right.y) * .5)
		result.head_rise = maxf(result.head_rise, probe.joint_world(rig, "bip01 head").y - initial_head)
		result.hind_drift = maxf(result.hind_drift, (probe.hind_midpoint(rig) - anchor).slide(Vector3.UP).length())
		result.paw_span = maxf(result.paw_span, left.distance_to(right))
	player.play("Idle", 0.0)
	player.advance(0.0)
	var idle_neck := probe.joint_world(rig, "bip01 neck").y
	var idle_paw := probe.joint_world(rig, "bip01 l hand").z
	player.play("BrownBearWakeAndRise" if body == 167 else "CougarUncoilAndStretch", 0.0)
	player.advance(0.0)
	result["rest_chest_drop"] = idle_neck - probe.joint_world(rig, "bip01 neck").y
	result["rest_paw_reach"] = probe.joint_world(rig, "bip01 l hand").z - idle_paw
	probe.free()
	assert(result.hind_drift < .004)
	assert(result.paw_height > (1.30 if body == 167 else .60), str(result))
	assert(result.paw_span > 1.2 if body == 167 else result.head_rise > .35, str(result))
	assert(result.rest_chest_drop > (.28 if body == 167 else .11), str(result))
	assert(result.rest_paw_reach > .25, str(result))
	return result
