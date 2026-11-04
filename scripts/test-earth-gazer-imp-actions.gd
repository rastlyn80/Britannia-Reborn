extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const BODIES := [14, 22, 74]
const TREATMENTS := ["original", "rounded", "modern"]
const FITTED := {14: [3, 4, 6, 15, 16, 18], 22: [3, 6, 18], 74: [15, 16]}

static func trial_row(body: int) -> Dictionary:
	if "--active" in OS.get_cmdline_user_args():
		var row := Registry.entry(body)
		assert(row.classic_gesture_batch == "earth_gazer_imp_actions")
		return row
	var path := "res://../work/creatures/earth_gazer_imp_actions/candidates.json"
	var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	for candidate: Dictionary in candidates:
		if int(candidate.body) == body:
			return candidate.presentation
	assert(false, "Missing prepared body")
	return {}

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var count := 0
	for body: int in BODIES:
		var base := Registry.entry(body)
		var row := trial_row(body)
		Registry.entries[body] = row
		game.entities[42] = {"serial": 42, "body": body, "hue": 0x8035}
		for treatment: String in TREATMENTS:
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			var player: AnimationPlayer = actor.animator
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var previous: String = Registry.asset_path(base, treatment)
			if base.get("classic_gesture_batch") == "earth_gazer_imp_actions":
				previous = base.classic_gesture_base_assets[treatment]
			Exact.check_earlier_keys(player, previous)
			var rig: Skeleton3D = actor.skeleton
			var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var skin := Ground.skin_points(mesh, rig)
			for key: String in row.classic_action_categories:
				var slot := int(key)
				actor.dead = false
				player.stop()
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(42, 4))
				packet.append_array(PackedByteArray([0, slot, 0, 5, 0, 1, 1, 0, 0]))
				game._handle(packet)
				assert(actor.receive_action(game.last_mobile_actions[42]) and actor.current_clip == row.classic_action_categories[key])
				if body == 14 and slot == 12:
					assert(not actor.contact.enabled)
				player.advance(0.0)
				for frame in 81:
					player.seek(player.current_animation_length * frame / 80.0, true)
					rig.force_update_all_bone_transforms()
					assert(actor.position.is_zero_approx() and actor.native_hue == 0x8035)
					var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
					assert(is_finite(gap))
					if slot in FITTED[body]:
						assert(gap > 0.0007, "%d slot %d ground clearance %f" % [body, slot, gap])
					if body == 22 and slot in [6, 18]:
						assert(gap > 0.30, "Gazer retains the source hover")
					if body == 22 and slot == 3 and frame == 80:
						assert(absf(gap - 0.002) < 0.001)
					count += 1
				if body == 22 and slot in [4, 5, 6]:
					assert(actor.sparks.all(func(spark: MeshInstance3D) -> bool: return not spark.visible))
					player.seek(player.current_animation_length * 0.65, true)
					assert(actor.sparks.all(func(spark: MeshInstance3D) -> bool: return spark.visible))
					for index in actor.sparks.size():
						var eye := rig.find_bone("gazers_gazer_eyebone%d" % (index + 1))
						var anchor := rig.to_global(rig.get_bone_global_pose(eye).origin)
						assert(actor.sparks[index].global_position.is_equal_approx(anchor))
			actor.free()
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse != null and corpse.get_meta("native_hue") == hue and corpse.get_meta("static_cadaver"))
			corpse.free()
	game.free()
	print("EARTH ELEMENTAL, GAZER AND IMP: ", count, " decoded poses, nine static corpse hues and retained source keys")
	quit()
