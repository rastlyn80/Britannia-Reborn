extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const ACTIONS := {
	21: {2: "Death", 3: "Death2", 4: "CoilSnap", 5: "Attack", 6: "LongStrike", 10: "Hit",
		11: "Pillage", 15: "NeckDrawback", 16: "LowNeckRecoil", 17: "Fidget", 18: "TailRipple"},
	1: {2: "Death", 3: "Death2", 4: "OverheadHammer", 5: "Attack", 6: "HighUppercut", 10: "Hit",
		11: "FaceWipe", 15: "ShoulderTurn", 16: "ChestBrace", 17: "Fidget", 18: "ShoulderScratch"},
}
const TREATMENTS := ["original", "rounded", "modern"]

static func trial_row(body: int) -> Dictionary:
	var base := Registry.entry(body)
	if "--active" in OS.get_cmdline_user_args():
		assert(base.classic_gesture_batch == "serpent_ogre_actions" and int(base.bodies[0].body) == body)
		return base
	var row := base.duplicate(true)
	row.assets = {}
	for treatment: String in TREATMENTS:
		row.assets[treatment] = "res://local-art/creatures/serpent-ogre-actions-%d-%s.scn" % [body, treatment]
	row.classic_action_categories = {}
	for slot: int in ACTIONS[body]:
		row.classic_action_categories[str(slot)] = ACTIONS[body][slot]
	row.presentation_script = ("res://Presentation/SourceQuadrupedCollapseVisual.gd" if body == 1
		else "res://Presentation/GiantSpiderActionsVisual.gd")
	return row

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	const SERIAL := 0x42
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var poses := 0
	for body: int in ACTIONS:
		var base := Registry.entry(body)
		Registry.entries[body] = trial_row(body)
		game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0x8035}
		for treatment: String in TREATMENTS:
			var visual := Registry.create(body)
			visual.treatment = treatment
			root.add_child(visual)
			visual.apply_identity(body, 0x8035)
			visual.set_process(false)
			visual.set_physics_process(false)
			var player: AnimationPlayer = visual.animator
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var previous := str(base.get("classic_gesture_base_assets", {}).get(treatment, Registry.asset_path(base, treatment)))
			Exact.check_earlier_keys(player, previous)
			var rig: Skeleton3D = visual.skeleton
			var mesh := visual.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var skin := Ground.skin_points(mesh, rig)
			var anchor := visual.global_transform
			var gaps := {}
			for slot: int in ACTIONS[body]:
				visual.dead = false
				player.stop()
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(SERIAL, 4))
				packet.append_array(PackedByteArray([0, slot, 0, 4, 0, 1, 1, 0, 0]))
				game._handle(packet)
				assert(visual.receive_action(game.last_mobile_actions[SERIAL]) and visual.current_clip == ACTIONS[body][slot])
				player.advance(0.0)
				var minimum := INF
				for frame in 81:
					player.seek(player.current_animation_length * frame / 80.0, true)
					rig.force_update_all_bone_transforms()
					var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
					assert(is_finite(gap) and visual.global_transform == anchor and visual.native_hue == 0x8035)
					minimum = minf(minimum, gap)
					poses += 1
				gaps[slot] = snappedf(minimum, 0.000001)
				if slot in [2, 3, 4, 6, 15, 16, 18]:
					assert(minimum > 0.0007, "%d %s slot %d clearance %f" % [body, treatment, slot, minimum])
			print(body, " ", treatment, " lowest sampled skin gaps ", gaps)
			visual.free()
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse != null and corpse.get_meta("native_hue") == hue and corpse.get_meta("static_cadaver"))
			corpse.free()
	game.free()
	print("GIANT SERPENT AND OGRE ACTIONS: ", poses, " decoded poses and original clip keys, six corpse hues")
	quit()
