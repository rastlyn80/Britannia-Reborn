extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const ACTIONS := {
	3: {2: "Death2", 3: "Death", 4: "BackhandReach", 5: "Attack", 6: "OverheadClaw",
		10: "Hit", 11: "ArmsRaise", 15: "DoubleOver", 16: "StaggerBack", 17: "Fidget", 18: "LookUp"},
	8: {2: "Death2", 3: "Death", 4: "InwardHook", 5: "Attack", 6: "DoubleLash",
		12: "Emerge", 17: "Fidget", 18: "TendrilCurl"},
	4: {2: "Death", 3: "Death2", 4: "RaisedWingRake", 5: "Attack", 6: "ForwardWingPunch",
		10: "Hit", 11: "KneelingLunge", 12: "Cast", 13: "KneelingStagger", 15: "CrouchRecoil",
		16: "OpenWingGuard", 17: "Fidget", 18: "WingDip", 21: "AirDeath"},
}
const FITTED := {3: [2, 4, 6, 15, 16, 18], 8: [2, 3, 4, 6, 18], 4: [3, 4, 6, 13, 15, 16, 18, 21]}
const ASSETS := {3: "zombie-actions", 8: "corpser-actions", 4: "gargoyle-actions"}
const VISUALS := {3: "SourceQuadrupedCollapseVisual", 8: "GiantSpiderActionsVisual", 4: "MongbatActionsVisual"}

static func trial_row(body: int) -> Dictionary:
	var row := Registry.entry(body).duplicate(true)
	if "--active" in OS.get_cmdline_user_args():
		assert(row.classic_gesture_batch == "zombie_corpser_gargoyle_actions")
		return row
	if body == 4:
		row.classic_gesture_base_assets = row.assets.duplicate()
		row.grounded_gestures = ["KneelingLunge", "Cast"]
	for treatment: String in row.assets:
		row.assets[treatment] = "res://local-art/creatures/%s-%s.scn" % [ASSETS[body], treatment]
	row.presentation_script = "res://Presentation/%s.gd" % VISUALS[body]
	for slot: int in ACTIONS[body]:
		row.classic_action_categories[str(slot)] = ACTIONS[body][slot]
	return row

func _initialize() -> void:
	create_timer(40.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	const SERIAL := 0x42
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var samples := 0
	for body: int in ACTIONS:
		var base := Registry.entry(body)
		var row := trial_row(body)
		Registry.entries[body] = row
		game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0x8035}
		for treatment: String in row.assets:
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			var animator: AnimationPlayer = actor.animator
			animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var previous: String = base.get("classic_gesture_base_assets", {}).get(treatment, Registry.asset_path(base, treatment))
			Exact.check_earlier_keys(animator, previous)
			if body == 8:
				check_emergence(animator, str(base.get("classic_gesture_base_assets", {}).get("modern", Registry.asset_path(base, "modern"))))
			var rig: Skeleton3D = actor.skeleton
			var skins: Array[Dictionary] = []
			for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
				if mesh.skin != null:
					skins.append(Ground.skin_points(mesh, rig))
			assert(not skins.is_empty())
			var expected: Dictionary = ACTIONS[body]
			for slot: int in expected:
				actor.dead = false
				animator.stop()
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(SERIAL, 4))
				packet.append_array(PackedByteArray([0, slot, 0, 4, 0, 1, 1, 0, 0]))
				game._handle(packet)
				assert(actor.receive_action(game.last_mobile_actions[SERIAL]) and actor.current_clip == expected[slot])
				animator.advance(0.0)
				var least := INF
				for frame in 81:
					animator.seek(animator.current_animation_length * frame / 80.0, true)
					rig.force_update_all_bone_transforms()
					if body == 8 and slot in [2, 3]:
						var core := rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 pelvis")).origin)
						assert(core.y < 0.62, "Rooted Corpser must stay planted, got core height %f" % core.y)
					for skin: Dictionary in skins:
						least = minf(least, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
					samples += 1
				assert(is_finite(least) and actor.native_hue == 0x8035)
				if slot in FITTED[body]:
					assert(least > 0.0007, "%d %s slot %d gap %f" % [body, treatment, slot, least])
			actor.free()
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse != null and corpse.get_meta("native_hue") == hue and corpse.get_meta("static_cadaver"))
			corpse.free()
	game.free()
	print("ZOMBIE, CORPSER AND GARGOYLE ACTIONS: ", samples, " decoded poses, original keys and nine static corpse hues")
	quit()


func check_emergence(player: AnimationPlayer, source: String) -> void:
	var prior := (load(source) as PackedScene).instantiate()
	var reference := prior.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var before := reference.get_animation("Emerge")
	var after := player.get_animation("Emerge")
	assert(before.length == after.length and before.get_track_count() == after.get_track_count())
	for track in before.get_track_count():
		assert(before.track_get_path(track) == after.track_get_path(track))
		assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track))
	prior.free()
