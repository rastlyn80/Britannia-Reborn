extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Actions := preload("res://../scripts/test-lizard-actions.gd")
const SERIAL := 0x4937

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	Registry.load_index()
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var count := 0
	for body: int in [35, 36]:
		Registry.entries[body] = Actions.trial_row(body)
		game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0x8035}
		for tilt: Vector3 in [Vector3.ZERO, Vector3(0.14, 0.0, -0.10), Vector3(-0.16, 0.0, 0.12)]:
			var ground := StaticBody3D.new()
			root.add_child(ground)
			ground.rotation = tilt
			var box := BoxShape3D.new()
			box.size = Vector3(8.0, 0.1, 8.0)
			var collider := CollisionShape3D.new()
			collider.shape = box
			collider.position.y = -0.05
			ground.add_child(collider)
			await physics_frame
			await physics_frame
			for slot: int in [2, 3]:
				var visual := Registry.create(body)
				root.add_child(visual)
				visual.apply_identity(body, 0x8035)
				visual.set_process(false)
				visual.set_physics_process(false)
				var anchor := visual.global_transform
				var rig: Skeleton3D = visual.skeleton
				var player: AnimationPlayer = visual.animator
				player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(SERIAL, 4))
				packet.append_array(PackedByteArray([0, slot, 0, 4, 0, 1, 1, 0, 0]))
				game._handle(packet)
				player.stop()
				assert(visual.receive_action(game.last_mobile_actions[SERIAL]) and visual.dead)
				player.advance(0.0)
				var least := INF
				for frame in 49:
					player.seek(player.current_animation_length * frame / 48.0, true)
					visual.support_collapse()
					var gap: float = visual.minimum_gap(rig.global_transform, ground.global_position, ground.global_basis.y)
					least = minf(least, gap)
					assert(visual.global_transform == anchor and is_finite(gap) and gap > -0.001,
						"Body %d group %d terrain %s frame %d gap %f" % [body, slot, tilt, frame, gap])
					count += 1
				print(body, " ", slot, " ", tilt, " minimum body/weapon gap ", least)
				visual.free()
			ground.free()
	game.free()
	print("LIZARD COLLAPSES: ", count, " decoded terrain poses, weapon clearance and authoritative root")
	quit()
