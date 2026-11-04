extends SceneTree

const Bounds := preload("res://Presentation/SkinGeometry.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")

func _initialize() -> void:
	create_timer(15.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var active := "--active" in OS.get_cmdline_user_args()
	for body in [53, 54, 55]:
		var record := Registry.entry(body).duplicate(true)
		if active:
			assert(record.status == "validated" and record.classic_action_categories["11"] == "KneelingSwing")
		else:
			record.assets = {"modern": "res://local-art/creatures/%s-slot11-trial.scn" % record.kind}
			record.classic_action_categories = record.get("classic_action_categories", {}).merged({"11": "KneelingSwing"}, true)
			Registry.entries[body] = record
		var actor := Registry.create(body)
		root.add_child(actor)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.apply_identity(body, 0x8035)
		var serial := 0x4100
		game.entities[serial] = {"serial": serial, "body": body, "hue": 0x8035}
		var packet := PackedByteArray([0x6e])
		packet.append_array(Wire.uint_be(serial, 4))
		packet.append_array(PackedByteArray([0, 11, 0, 5, 0, 1, 1, 0, 0]))
		game._handle(packet)
		assert(actor.receive_action(game.last_mobile_actions[serial]) and actor.current_clip == "KneelingSwing")
		assert(actor.native_body == body and actor.native_hue == 0x8035)
		var root_transform := actor.global_transform
		var player: AnimationPlayer = actor.animator
		var rig: Skeleton3D = actor.skeleton
		var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var knees := [rig.find_bone("bip01 r calf"), rig.find_bone("bip01 l calf")]
		var head := rig.find_bone("bip01 head")
		var hands := [rig.find_bone("bip01 r hand"), rig.find_bone("bip01 l hand")]
		var hip := rig.find_bone("bip01 pelvis")
		var floor := INF
		var knee := INF
		var high := -INF
		var brace := -INF
		var hips := INF
		var start := 0.0
		player.play("KneelingSwing", 0.0)
		player.advance(0.0)
		for i in 121:
			player.seek(player.get_animation("KneelingSwing").length * float(i) / 120.0, true)
			rig.force_update_all_bone_transforms()
			var bounds := Bounds.deformed_bounds(mesh, rig)
			floor = minf(floor, bounds.position.y)
			var head_y := rig.to_global(rig.get_bone_global_pose(head).origin).y
			high = maxf(high, rig.to_global(rig.get_bone_global_pose(hands[0]).origin).y - head_y)
			brace = maxf(brace, rig.to_global(rig.get_bone_global_pose(hands[1]).origin).y - head_y)
			var hip_y := rig.to_global(rig.get_bone_global_pose(hip).origin).y
			if i == 0:
				start = hip_y
			hips = minf(hips, hip_y)
			knee = minf(knee, maxf(rig.to_global(rig.get_bone_global_pose(knees[0]).origin).y,
				rig.to_global(rig.get_bone_global_pose(knees[1]).origin).y))
			assert(actor.global_transform.is_equal_approx(root_transform))
		print(body, " floor/knee/raised wrist/brace wrist/hip drop ", [floor, knee, high, brace, start - hips])
		assert(floor > -0.005 and knee < 0.48 and high > 0.08 and brace < -0.25 and start - hips > 0.55)
		actor.free()
	game.free()
	quit()
