extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Game := preload("res://Network/GameSession.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const ACTIONS := {
	202: {4: "Alert", 6: "JawLunge", 8: "Death", 10: "SlowLook", 12: "Death2"},
	24: {2: "Death", 3: "Death2", 13: "StaffStagger", 14: "Cast", 15: "HandGuard",
		16: "StaffBrace", 18: "StaffShift"},
}

static func trial_row(body: int) -> Dictionary:
	if "--active" in OS.get_cmdline_user_args():
		var row := Registry.entry(body)
		assert(row.classic_gesture_batch == "alligator_lich_actions")
		return row
	var path := "res://../work/creatures/alligator_lich_actions/candidates.json"
	var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
	for candidate: Dictionary in candidates:
		if int(candidate.body) == body:
			return candidate.presentation
	assert(false, "Missing prepared body")
	return {}

func _initialize() -> void:
	create_timer(80.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var poses := 0
	for body: int in ACTIONS:
		var base := Registry.entry(body)
		var row := trial_row(body)
		Registry.entries[body] = row
		game.entities[42] = {"serial": 42, "body": body, "hue": 0x8035}
		for treatment: String in ["original", "rounded", "modern"]:
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			var player: AnimationPlayer = actor.animator
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var rig: Skeleton3D = actor.skeleton
			var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var skin := Ground.skin_points(mesh, rig)
			var prior: String = Registry.asset_path(base, treatment)
			if base.get("classic_gesture_batch") == "alligator_lich_actions":
				prior = base.classic_gesture_base_assets[treatment]
			Exact.check_earlier_keys(player, prior)
			for slot: int in ACTIONS[body]:
				player.stop()
				actor.dead = false
				var request := PackedByteArray([0x6e])
				request.append_array(Wire.uint_be(42, 4))
				request.append_array(PackedByteArray([0, slot, 0, 5, 0, 1, 1, 0, 0]))
				game._handle(request)
				assert(actor.receive_action(game.last_mobile_actions[42]) and actor.current_clip == ACTIONS[body][slot])
				player.play(actor.current_clip, 0.0)
				player.advance(0.0)
				for frame in 81:
					player.seek(player.current_animation_length * frame / 80.0, true)
					rig.force_update_all_bone_transforms()
					assert(actor.position.is_zero_approx() and actor.native_hue == 0x8035)
					if body == 202:
						var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
						assert(gap > -0.001, "%d slot %d floor %f" % [body, slot, gap])
					if body == 24 and treatment == "modern":
						var normal: Vector3 = actor.support_normal()
						var gap: float = actor.staff_gap(actor.staff.global_transform, normal)
						gap += actor.model.global_position.dot(normal)
						assert(gap > -0.001, "Lich staff crossed the surface in slot %d" % slot)
					poses += 1
			actor.free()
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse != null and corpse.get_meta("native_hue") == hue and corpse.get_meta("static_cadaver"))
			corpse.free()
	game.free()
	print("ALLIGATOR AND LICH: ", poses, " decoded poses, retained source keys and six static corpse hues")
	quit()
