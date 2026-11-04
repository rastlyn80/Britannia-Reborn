extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Game := preload("res://Network/GameSession.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const ROUTES := {
	124: {2: "Death", 3: "Death", 6: "RaisedCast", 12: "Cast2", 14: "Cast2", 15: "WardRecoil", 16: "WardRecoil", 18: "StafflessBend"},
	240: {11: "Fidget", 15: "ShellRecoilLeft", 16: "ShellRecoilRight", 17: "JawAlert", 18: "Fidget"},
	250: {11: "Fidget", 15: "PackGuardLeft", 16: "PackGuardRight", 17: "ThreeHeadAlert", 18: "Fidget"},
	779: {15: "RootGuard", 16: "RootGuard", 18: "Uncurl"},
}

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/occurrence_gestures/candidates.json"))
		assert(rows.size() == ROUTES.size())
		for candidate: Dictionary in rows:
			Registry.entries[int(candidate.body)] = candidate.presentation
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var samples := 0
	for body: int in ROUTES:
		var row := Registry.entry(body)
		var gestures: Dictionary = ROUTES[body]
		var treatments := ["modern"] if body == 779 else ["original", "rounded", "modern"]
		game.entities[42] = {"serial": 42, "body": body}
		for treatment: String in treatments:
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.set_process(false)
			actor.set_physics_process(false)
			var hue := 0x8035
			actor.apply_identity(body, hue)
			var player: AnimationPlayer = actor.animator
			var base_path: String = row.classic_gesture_base_assets[treatment]
			Exact.check_earlier_keys(player, base_path)
			var rig: Skeleton3D = actor.skeleton
			var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var skin := Ground.skin_points(mesh, rig)
			for slot: int in gestures:
				actor.dead = false
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(42, 4))
				packet.append_array(PackedByteArray([0, slot, 0, 5, 0, 1, 1, 0, 0]))
				game._handle(packet)
				assert(actor.receive_action(game.last_mobile_actions[42]) and actor.current_clip == gestures[slot])
				player.play(actor.current_clip, 0.0)
				player.advance(0.0)
				var least := INF
				var highest := -INF
				for frame in 61:
					player.seek(player.current_animation_length * float(frame) / 60.0, true)
					rig.force_update_all_bone_transforms()
					var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
					assert(is_finite(gap) and actor.native_hue == hue and actor.position.is_zero_approx())
					least = minf(least, gap)
					highest = maxf(highest, gap)
					samples += 1
				var fitted := slot in [6, 15, 16, 17, 18] and not (body in [240,250] and slot == 18)
				if fitted:
					assert(least > -0.014 and highest < 0.045, "Body %d group %d gap %s..%s" % [body,slot,least,highest])
				if body == 779:
					var material := mesh.get_active_material(0) as ShaderMaterial
					assert(material.shader.resource_path.ends_with("BoglingSurface.gdshader") and material.get_shader_parameter("partial_hue") == true)
				print(body, " ", treatment, " ", slot, " ", actor.current_clip, " floor ", least, "..", highest)
			actor.free()
		for hue in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse != null and corpse.get_meta("graphic_id") == 0x2006)
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue)
			assert(corpse.find_children("*", "AnimationPlayer", true, false).is_empty())
			assert(not corpse.find_children("*", "MeshInstance3D", true, false).is_empty())
			corpse.free()
	game.free()
	print("OCCURRENCE GESTURES: ", samples, " decoded poses with retained keys and 12 static cadaver hues")
	quit()


