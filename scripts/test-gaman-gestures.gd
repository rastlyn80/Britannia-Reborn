extends SceneTree
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const SealedBase := preload("res://Presentation/SealedCreatureActionBase.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Game := preload("res://Network/GameSession.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var row := Registry.entry(248)
	if row.get("classic_gesture_batch") == "post_solen_actions":
		row = SealedBase.retained(row, 248)
		Registry.entries[248] = row
	assert(row.classic_gesture_batch == "gaman_gestures")
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[42] = {"serial": 42, "body": 248}
	var samples := 0
	for treatment: String in ["original", "rounded", "modern"]:
		var actor := Registry.create(248)
		actor.treatment = treatment
		root.add_child(actor)
		actor.apply_identity(248, 0x8035)
		actor.set_process(false)
		actor.set_physics_process(false)
		var player: AnimationPlayer = actor.animator
		var rig: Skeleton3D = actor.skeleton
		var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh, rig)
		var head := rig.find_bone("bip01 head")
		var trajectories := {}
		for slot: int in [9,10]:
			var packet := PackedByteArray([0x6e])
			packet.append_array(Wire.uint_be(42,4))
			packet.append_array(PackedByteArray([0,slot,0,5,0,1,1,0,0]))
			game._handle(packet)
			assert(actor.receive_action(game.last_mobile_actions[42]))
			assert(actor.current_clip == row.classic_action_categories[str(slot)])
			player.play(actor.current_clip,0.0)
			player.advance(0.0)
			var motion := PackedVector3Array()
			for frame in 61:
				player.seek(player.current_animation_length * frame / 60.0,true)
				rig.force_update_all_bone_transforms()
				motion.append(rig.to_global(rig.get_bone_global_pose(head).origin))
				var gap := Ground.minimum_plane_gap(skin,rig,rig.global_transform,Vector3.ZERO,Vector3.UP)
				assert(gap > -0.003 and actor.native_hue==0x8035 and actor.position.is_zero_approx())
				samples += 1
			trajectories[slot] = motion
		assert(trajectories[9][0].distance_to(trajectories[10][0]) > 0.20)
		actor.free()
	game.free()
	print("GAMAN: ",samples," local decoded samples across two exact recovered clips")
	quit()
