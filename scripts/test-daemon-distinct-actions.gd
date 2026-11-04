extends SceneTree
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Game := preload("res://Network/GameSession.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const CANDIDATES := "res://../work/creatures/daemon_wyvern_polar_actions/candidates.json"

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	call_deferred("run")

const ROUTES := {
	9: {3: "Death2", 6: "LowRake", 13: "WingShoulderStagger", 15: "ChestGuard",
		16: "LowForearmGuard", 18: "TailPause", 21: "AirDeath"},
	62: {3: "Death2", 15: "WingRecoil", 16: "WingRecoil", 17: "Fidget", 18: "WingRear", 21: "AirDeath"},
	213: {4: "MuzzleLift", 5: "PolarRearStrike", 6: "Attack", 8: "Death", 9: "Fidget", 10: "HindCrouch", 12: "Death2"},
}

func run() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATES))
		assert(rows.size() == 3)
		for row: Dictionary in rows:
			Registry.entries[int(row.body)] = row.presentation
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var samples := 0
	for body: int in ROUTES:
		var row := Registry.entry(body)
		assert(row.get("classic_gesture_batch", row.family) == "daemon_wyvern_polar_actions")
		game.entities[42] = {"serial": 42, "body": body}
		for treatment: String in ["original", "rounded", "modern"]:
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			var player: AnimationPlayer = actor.animator
			Exact.check_earlier_keys(player, row.classic_gesture_base_assets[treatment])
			var rig: Skeleton3D = actor.skeleton
			var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var skin := Ground.skin_points(mesh, rig)
			for slot: int in ROUTES[body]:
				actor.dead = false
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(42, 4))
				packet.append_array(PackedByteArray([0, slot, 0, 5, 0, 1, 1, 0, 0]))
				game._handle(packet)
				assert(actor.receive_action(game.last_mobile_actions[42]) and actor.current_clip == ROUTES[body][slot])
				player.play(actor.current_clip, 0.0)
				player.advance(0.0)
				var start_floor := 0.0
				var end_floor := 0.0
				var least := INF
				for frame in 61:
					player.seek(player.current_animation_length * frame / 60.0, true)
					rig.force_update_all_bone_transforms()
					var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
					assert(is_finite(gap) and actor.native_hue == 0x8035 and actor.position.is_zero_approx())
					if frame == 0:
						start_floor = gap
					end_floor = gap
					least = minf(least, gap)
					samples += 1
				if (body == 62 and slot != 17) or (body == 213 and slot not in [8, 9]) or body == 9:
					assert(least > -0.002, "Body %d group %d crossed its floor by %.4fm" % [body, slot, least])
				if slot == 21:
					assert(start_floor > (1.4 if body == 9 else 0.85) and end_floor > 0.0 and end_floor < 0.008)
					check_landing_height(body, rig, player, "Death" if body == 9 else "Death2", 0.50 if body == 9 else 0.11)
				elif body == 9 and slot == 3:
					check_landing_height(body, rig, player, "Death", 0.18)
			actor.free()
	game.free()
	print("DAEMON, WYVERN AND POLAR BEAR: ", samples, " decoded poses with retained source keys and native raw hue")
	quit()

func check_landing_height(body: int, rig: Skeleton3D, player: AnimationPlayer, reference: String, margin: float) -> void:
	var hips := rig.find_bone("bip01 pelvis")
	var landing := rig.to_global(rig.get_bone_global_pose(hips).origin).y
	player.play(reference, 0.0)
	player.advance(0.0)
	player.seek(player.current_animation_length, true)
	rig.force_update_all_bone_transforms()
	var source := rig.to_global(rig.get_bone_global_pose(hips).origin).y
	assert(absf(landing - source) < margin, "Body %d landed with its hips %.2fm above the recovered pose" % [body, landing - source])
