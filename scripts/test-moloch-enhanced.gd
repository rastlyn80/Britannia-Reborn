# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Fit := preload("bake-moloch-enhanced.gd")
const RendererPath := "res://Presentation/SourceEnhancedMolochVisual.gd"
const Visual := preload(RendererPath)
const Actions := preload("res://Presentation/EnhancedCreatureAttackActions.gd")
const Corpse := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Profile := preload("res://Presentation/EnhancedCreatureProfile.gd")
const JointsToTrace := ["bip01 head", "bip01 l hand", "bip01 r hand", "mesh03", "mesh12"]


func run() -> void:
	var body := Fit.Body
	var base := Registry.entry(body)
	var row := base.duplicate(true)
	row.presentation_script = RendererPath
	for treatment: String in row.assets:
		row.assets[treatment] = Fit.Destination + "%d-%s.scn" % [body, treatment]
	var names := Fit.Clips
	var routes := {"2": [names[15], names[15]], "3": ["Death", "Death2"], "4": [names[10]],
		"5": [names[26], names[27]], "8": [names[28]], "11": [names[12], names[12], names[12]],
		"14": [names[11]], "15": [names[23]]}
	var attacks := {"0": [names[4], names[5], names[4]], "1": [names[4]], "2": [names[4]], "9": [names[4]],
		"255": [names[4], names[5], names[4], names[4], names[4], names[4]]}
	row.enhanced_source_action_groups = {"0": routes, "1": {"5": [names[26]]}}
	row.enhanced_attack_subactions = attacks
	if "--installed" in OS.get_cmdline_user_args():
		var installed := Profile.read_rows(Profile.MANIFEST, Profile.SCENES)
		assert(installed.has(body))
		row = installed[body]
		assert(row.presentation_script == RendererPath)
		assert(row.enhanced_source_action_groups == {"0": routes, "1": {"5": [names[26]]}})
		assert(row.enhanced_attack_subactions == attacks)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
	var report := {"routes": 0, "falls": 0, "fall_poses": 0, "maximum_jump": 0.0, "minimum_floor": INF, "hashes": {}}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := make_actor(row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				Fit.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
				report.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				for flags: int in [0, 64]:
					actor.set_native_combat_flags(flags)
					actor.play_gait(false, 0.0)
					assert(actor.current_clip == (names[1] if flags == 64 else names[25]))
					actor.play_gait(true, 1.8)
					assert(actor.current_clip == ("Walk" if flags == 64 else Fit.PeaceWalk))
					report.routes += 2
					for kind: String in routes:
						var choices: Array = row.enhanced_source_action_groups["0" if flags else "1"].get(kind, routes[kind])
						for variant in [0, 1, 2, 5, 127]:
							actor.dead = false
							assert(Actions.dispatch(avatar, packet(game, int(kind), 0, variant), true, flags))
							assert(actor.current_clip == choices[variant % choices.size()])
							report.routes += 1
					for subaction in [0, 1, 2, 9, 37, 0x100, 0x101, 0x1ff]:
						var choices: Array = attacks.get(str(subaction & 255), attacks["255"])
						for variant in [0, 1, 2, 5, 127]:
							actor.dead = false
							assert(Actions.dispatch(avatar, packet(game, 0, subaction, variant), true, flags))
							assert(actor.current_clip == choices[variant % choices.size()])
							report.routes += 1
					actor.action_remaining = 0.0
			for phase: float in [.22, .63]:
				actor.dead = false
				assert(Actions.dispatch(avatar, packet(game, 3, 0, 1), true, 64))
				actor.animator.advance(.17)
				actor.animator.seek(phase * actor.animator.current_animation_length, true)
				actor.skeleton.force_update_all_bone_transforms()
				check_death(actor, row, floor, report)
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	game.free()
	assert(report.routes == 492 and report.falls == 30 and report.fall_poses == 480)
	report.renderer_sha256 = FileAccess.get_sha256(RendererPath)
	var file := FileAccess.open(Fit.Destination + "runtime-receipt.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("MOLOCH FITTED RUNTIME: ", report)
	quit()


func make_actor(row: Dictionary, treatment: String) -> Node3D:
	var actor := Visual.new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(Fit.Body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func check_death(actor: Node3D, row: Dictionary, floor: StaticBody3D, report: Dictionary) -> void:
	var fallen := make_actor(row, actor.treatment)
	fallen.model.transform = actor.model.transform
	assert(fallen.begin_death_from(actor) > 0.0 and fallen.current_clip == "Death2")
	for bone: String in JointsToTrace:
		var jump := landmark(actor, bone).distance_to(landmark(fallen, bone))
		assert(jump < .0025, "Moloch alternate fall handoff jumped %.6f" % jump)
		report.maximum_jump = maxf(report.maximum_jump, jump)
	var mesh := fallen.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, fallen.skeleton)
	var from: float = fallen.animator.current_animation_position
	for phase in range(1, 17):
		fallen.animator.seek(lerpf(from, fallen.animator.current_animation_length, phase / 16.0), true)
		fallen.skeleton.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(skin, fallen.skeleton, fallen.skeleton.global_transform, floor.position, floor.basis.y)
		assert(gap >= .001, "Moloch alternate fall penetrated terrain")
		report.minimum_floor = minf(report.minimum_floor, gap)
		report.fall_poses += 1
	var frozen := Corpse.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not frozen.is_empty() and frozen.body == Fit.Body)
	report.falls += 1
	fallen.free()


static func packet(game: Node, kind: int, subaction: int, variation: int) -> Dictionary:
	var raw := PackedByteArray([0xe2])
	raw.append_array(Wire.uint_be(Fit.Body, 4))
	raw.append_array(Wire.uint_be(kind, 2))
	raw.append_array(Wire.uint_be(subaction, 2))
	raw.append(variation)
	var received := [{}]
	game.mobile_action_received.connect(func(action: Dictionary): received[0] = action, CONNECT_ONE_SHOT)
	game._handle(raw)
	return received[0]
