extends "res://../scripts/test-occurrence-gestures.gd"

const FITTED := {124: [6, 15, 18], 240: [15, 16, 17], 250: [15, 16, 17], 779: [15, 18]}

func run() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/occurrence_gestures/candidates.json"))
		assert(rows.size() == FITTED.size())
		for row: Dictionary in rows:
			Registry.entries[int(row.body)] = row.presentation
	var ground := StaticBody3D.new()
	var surface := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12, 0.10, 12)
	surface.shape = box
	surface.position.y = -0.05
	ground.add_child(surface)
	root.add_child(ground)
	var samples := 0
	for tilt: Vector3 in [Vector3.ZERO, Vector3(0.08, 0.0, -0.07), Vector3(-0.07, 0.0, 0.08)]:
		ground.rotation = tilt
		await physics_frame
		await physics_frame
		for body: int in FITTED:
			var actor := Registry.create(body)
			root.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			var player: AnimationPlayer = actor.animator
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var rig: Skeleton3D = actor.skeleton
			var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var skin := Ground.skin_points(mesh, rig)
			var normal := ground.global_basis.y.normalized()
			for slot: int in FITTED[body]:
				assert(actor.receive_action({"protocol": "classic", "action": slot, "frames": 5}))
				player.play(actor.current_clip, 0.0)
				player.advance(0.0)
				var least := INF
				var highest := -INF
				for frame in 51:
					player.seek(player.current_animation_length * float(frame) / 50.0, true)
					rig.force_update_all_bone_transforms()
					actor._physics_process(0.5)
					actor.contact._process_modification_with_delta(1.0 / 60.0)
					rig.force_update_all_bone_transforms()
					var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, ground.global_position, normal)
					assert(is_finite(gap) and actor.position.is_zero_approx() and actor.contact.contacts.size() >= 2)
					least = minf(least, gap)
					highest = maxf(highest, gap)
					samples += 1
				print(body, " group ", slot, " tilt ", tilt, " gap ", least, "..", highest)
				assert(least > -0.015 and highest < 0.035, "The fitted motion crosses or floats over finite terrain")
			actor.free()
	ground.free()
	print("OCCURRENCE GESTURES: ", samples, " complete weighted skins over finite terrain")
	quit()

