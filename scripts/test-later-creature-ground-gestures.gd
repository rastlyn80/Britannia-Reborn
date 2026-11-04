extends "res://../scripts/test-later-creature-gestures.gd"

const GROUND_ACTIONS := {57: [5, 6, 15, 16, 18], 128: [15, 18], 775: [15, 18]}

func run() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/later_creature_gestures/candidates.json"))
		assert(rows.size() == 6)
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
		for body: int in GROUND_ACTIONS:
			var actor := Registry.create(body)
			root.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			var player: AnimationPlayer = actor.animator
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var rig: Skeleton3D = actor.skeleton
			var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var skins := [Ground.skin_points(mesh, rig)]
			if body == 57:
				for name: String in LOADOUTS[57]:
					var prop := actor.find_child(name, true, false) as MeshInstance3D
					skins.append(Ground.skin_points(prop, rig))
			var normal := ground.global_basis.y.normalized()
			for slot: int in GROUND_ACTIONS[body]:
				assert(actor.receive_action({"protocol": "classic", "action": slot, "frames": 5}))
				player.stop()
				player.play(actor.current_clip, 0.0)
				player.advance(0.0)
				var least := INF
				var highest := -INF
				for frame in 51:
					player.seek(player.current_animation_length * float(frame) / 50.0, true)
					rig.force_update_all_bone_transforms()
					actor._physics_process(0.5)
					actor.contact._process_modification_with_delta(1.0 / 60.0)
					if body == 57:
						actor.clear_gesture_ground()
					rig.force_update_all_bone_transforms()
					var gap := INF
					for skin: Dictionary in skins:
						gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, ground.global_position, normal))
					assert(is_finite(gap) and actor.position.is_zero_approx() and not actor.contact.contacts.is_empty())
					least = minf(least, gap)
					highest = maxf(highest, gap)
					samples += 1
				print(body, " group ", slot, " tilt ", tilt, " gap ", least, "..", highest)
				var spiral := body == 128 and slot == 18
				assert(least > -0.015 and highest < (0.32 if spiral else 0.035),
					"The fitted motion crosses or floats over finite terrain")
				if spiral:
					assert(highest > 0.24, "The Pixie retains its full airborne arc")
			actor.free()
	ground.free()
	print("LATER GROUND GESTURES: ", samples, " complete weighted skins over finite terrain")
	quit()
