extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const CANDIDATES := "res://../work/creatures/tokuno_spider_dragon_actions/candidates.json"
const DRAGON := {2:"Death", 3:"Death2", 6:"WingRake", 11:"DragonDip", 12:"DragonBreath",
	15:"FoldedFlinch", 16:"LowWingGuard", 18:"WingLift", 21:"AirDeath"}
const ROUTES := {245:{11:"Fidget", 15:"YomotsuRecoil", 16:"YomotsuRecoil", 17:"WeaponRest", 18:"Fidget"},
	11:{2:"Death", 3:"Death2", 11:"Fidget", 15:"DreadReach", 16:"DreadReach", 17:"Fidget", 18:"DreadRock"},
	12:DRAGON, 59:DRAGON}
const FITTED := {245:[15,16,17], 11:[3,15,16,18], 12:[2,6,15,16,18,21], 59:[2,6,15,16,18,21]}

func _initialize() -> void:
	create_timer(55.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func load_routes() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATES))
		assert(rows.size() == 6)
		for row: Dictionary in rows:
			Registry.entries[int(row.body)] = row.presentation

func run() -> void:
	load_routes()
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var samples := 0
	for body: int in ROUTES:
		var row := Registry.entry(body)
		game.entities[body] = {"serial":body, "body":body, "hue":0x8035}
		for treatment: String in ["original", "rounded", "modern"]:
			assert(FileAccess.get_sha256(row.assets[treatment]) == row.authored_action_scene_sha256[treatment])
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			var rig: Skeleton3D = actor.skeleton
			var player: AnimationPlayer = actor.animator
			Exact.check_earlier_keys(player, row.classic_gesture_base_assets[treatment])
			var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var skin := Ground.skin_points(mesh, rig)
			for slot: int in ROUTES[body]:
				actor.dead = false
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(body, 4))
				packet.append_array(PackedByteArray([0, slot, 0, 5, 0, 1, 1, 0, 0]))
				game._handle(packet)
				assert(actor.receive_action(game.last_mobile_actions[body]) and actor.current_clip == ROUTES[body][slot])
				player.play(actor.current_clip, 0.0)
				player.advance(0.0)
				var gaps: Array[float] = []
				for frame in 61:
					player.seek(player.current_animation_length * float(frame) / 60.0, true)
					rig.force_update_all_bone_transforms()
					gaps.append(Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
					assert(is_finite(gaps[-1]) and actor.native_hue == 0x8035 and actor.position.is_zero_approx())
					samples += 1
				if slot in FITTED[body]:
					assert(gaps.min() > -0.007, "Body %d group %d crossed its floor by %.4fm" % [body, slot, gaps.min()])
				if slot == 12 and body in [12, 59]:
					var muzzle := rig.find_bone("box15")
					assert(muzzle >= 0 and actor.fire_breath_origin().is_equal_approx(rig.to_global(rig.get_bone_global_pose(muzzle).origin)))
				if slot == 21:
					assert(gaps[0] > 1.8 and gaps[-1] > 0.0 and gaps[-1] < 0.008)
			actor.free()
		for hue: int in [0, 53, 0x8035]:
			var cadaver := Corpses.build(body, hue)
			assert(cadaver != null and cadaver.get_meta("static_cadaver") and cadaver.get_meta("graphic_id") == 0x2006)
			assert(cadaver.get_meta("corpse_body") == body and cadaver.get_meta("native_hue") == hue)
			assert(cadaver.find_children("*", "Skeleton3D", true, false).is_empty())
			cadaver.free()
	var sibling := Registry.create(19)
	root.add_child(sibling)
	sibling.apply_identity(19, 0)
	assert(sibling.entry.kind == "arachnids_spider_dread" and not sibling.receive_action({"protocol":"classic", "action":11}))
	assert(not sibling.animator.has_animation("DreadReach"))
	sibling.free()
	game.free()
	print("YOMOTSU, DREAD SPIDER AND DRAGONS: ", samples, " decoded poses and 12 static corpse hues; body 19 retained")
	quit()
