# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/corpser-boar/"
const Plant := "res://Presentation/SourceEnhancedCorpserVisual.gd"
const Modes := {
	8: {"0": {"2": ["CorpserClosedCanopy", "CorpserClosedCanopy"],
		"5": ["CorpserClosePetals", "CorpserSplay"], "8": ["CorpserRaisedTendrils"],
		"11": ["CorpserTripleSweep", "CorpserTripleSweep", "CorpserTripleSweep"],
		"14": ["CorpserQuietBloom"], "15": ["Emerge"]}, "1": {"5": ["CorpserClosePetals"]}},
	290: {"0": {"2": ["BoarSnoutRecoil", "BoarSnoutRecoil"],
		"5": ["BoarScentCheck", "BoarLowGuard"], "8": ["BoarEarAlert"],
		"11": ["BoarTuskFlick", "BoarTuskFlick", "BoarTuskFlick"],
		"14": ["BoarQuietStand"], "15": ["BoarQuietStand"]}, "1": {"5": ["BoarScentCheck"]}},
}

func run() -> void:
	var bases := {8: Registry.entry(8), 290: Registry.entry(290)}
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
		var file := FileAccess.open(Stage + "corpser-boar-candidate.json", FileAccess.WRITE)
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
		row.archive_grounded_gestures = clips.keys().filter(func(clip: String): return clip != "Emerge")
		row.presentation_script = Plant if body == 8 else "res://Presentation/SourceEnhancedFieldVisual.gd"
		for treatment: String in row.assets:
			row.assets[treatment] = Stage + "%d-%s.scn" % [body, treatment]
		Registry.entries[body] = row
	assert(row.enhanced_source_action_groups == modes)
	game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
	var counts := Vector2i.ZERO
	var poses := 0
	var gaps := {}
	var emergences := 0
	var trunk_drift := 0.0
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
			for clip: String in clips:
				var selection: Array = clips[clip]
				var packet := decode(game, body, selection[0], selection[1])
				if clip == "Emerge":
					check_emergence(avatar, packet)
					emergences += 1
					continue
				var gap: float
				if body == 8:
					var planted := sample_plant(avatar, floor, packet, clip)
					gap = planted.x
					trunk_drift = maxf(trunk_drift, planted.y)
				else:
					gap = sample(avatar, floor, packet, clip)
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
	assert(counts == Vector2i(144, 108) and poses == 2790)
	assert(emergences == (15 if body == 8 else 0))
	print("CORPSER AND BOAR ", body, ": ", counts, " ", poses, " terrain poses, ", emergences, " emergences, trunk shift ", trunk_drift, " ", gaps)
	return {"routes": counts.x, "classic_comparisons": counts.y, "terrain_poses": poses,
		"gaps": gaps, "trunk_drift": trunk_drift, "emergences": emergences, "corpse_hues": 3, "scene_sha256": hashes}


func check_emergence(avatar: Avatar, packet: Dictionary) -> void:
	var actor := avatar.horse_visual
	var player: AnimationPlayer = actor.animator
	var mesh: MeshInstance3D = actor.model.find_children("*", "MeshInstance3D", true, false)[0]
	var geometry := preload("res://Presentation/SkinGeometry.gd")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	assert(Dispatch.dispatch(avatar, packet, true, 0x40) and actor.current_clip == "Emerge")
	player.advance(.13)
	player.seek(0.0, true)
	actor.skeleton.force_update_all_bone_transforms()
	var start := geometry.deformed_bounds(mesh, actor.skeleton).end.y
	player.seek(player.current_animation_length, true)
	actor.skeleton.force_update_all_bone_transforms()
	var finish := geometry.deformed_bounds(mesh, actor.skeleton).end.y
	assert(start < .06 and finish > 1.9, "%s to %s" % [start, finish])

func sample_plant(avatar: Avatar, floor: StaticBody3D, packet: Dictionary, clip: String) -> Vector2:
	var actor := avatar.horse_visual
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var mesh: MeshInstance3D = actor.model.find_children("*", "MeshInstance3D", true, false)[0]
	var skin := Ground.skin_points(mesh, rig)
	var joint := rig.find_bone("bip01 pelvis")
	var anchor: Transform3D = actor.global_transform
	var normal := floor.basis.y
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	assert(Dispatch.dispatch(avatar, packet, true, 0x40) and actor.current_clip == clip)
	player.advance(.13)
	var gap := INF
	var lowest := INF
	var highest := -INF
	for index in 31:
		player.seek(player.current_animation_length * index / 30.0, true)
		actor._physics_process(1.0 / 60.0)
		rig.force_update_all_bone_transforms()
		assert(actor.planted and not actor.contact.enabled and actor.global_transform.is_equal_approx(anchor))
		gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, floor.position, normal))
		var trunk: Vector3 = rig.to_global(rig.get_bone_global_pose(joint).origin)
		var height := normal.dot(trunk - floor.position)
		lowest = minf(lowest, height)
		highest = maxf(highest, height)
	assert(highest - lowest < .075, "%s floats: %f" % [clip, highest - lowest])
	return Vector2(gap, highest - lowest)
