extends "res://../scripts/test-ophidian-patchwork-actions.gd"

const GROUND_ACTIONS := {86:[5,6,15,16,18], 309:[15,18]}

func run() -> void:
	load_routes()
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
			if body == 86:
				skins.append(actor.bardiche_skin)
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
					rig.force_update_all_bone_transforms()
					var gap := INF
					for skin: Dictionary in skins:
						gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, ground.global_position, normal))
					assert(is_finite(gap) and actor.position.is_zero_approx())
					least = minf(least, gap)
					highest = maxf(highest, gap)
					samples += 1
				print(body, " group ", slot, " tilt ", tilt, " gap ", least, "..", highest)
				if body == 86:
					assert(least > 0.0029 and highest < 0.0031)
				else:
					assert(least > -0.015 and highest < 0.04)
			actor.free()
	ground.free()
	print("OPHIDIAN AND PATCHWORK TERRAIN: ", samples, " complete weighted skins over finite terrain")
	quit()
