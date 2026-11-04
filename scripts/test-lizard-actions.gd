extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const SERIAL := 0x4114
const SLOTS := {2: "Death2", 3: "Death", 4: "ClassicOverhead", 5: "Attack2", 6: "Attack3", 10: "Hit", 15: "RightGuard", 16: "LeftGuard", 17: "Fidget", 18: "Fidget2"}

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var count := 0
	for body: int in [35, 36]:
		var base := Registry.entry(body)
		var path: String = base.get("classic_gesture_base_assets", base.assets).modern
		var row := trial_row(body)
		Registry.entries[body] = row
		game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0x8035}
		var visual := Registry.create(body)
		root.add_child(visual)
		visual.apply_identity(body, 0x8035)
		visual.set_process(false)
		visual.set_physics_process(false)
		var player: AnimationPlayer = visual.animator
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var rig: Skeleton3D = visual.skeleton
		var prior := (load(path) as PackedScene).instantiate()
		var prior_player := prior.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		for clip: String in prior_player.get_animation_list():
			var previous := prior_player.get_animation(clip)
			var current := player.get_animation(clip)
			assert(previous.length == current.length and previous.get_track_count() == current.get_track_count())
			for track in previous.get_track_count():
				assert(previous.get("tracks/%d/keys" % track) == current.get("tracks/%d/keys" % track))
		prior.free()
		var anchor := visual.global_transform
		var head := rig.find_bone("bip01 head")
		var hip := rig.find_bone("bip01 pelvis")
		var hand := rig.find_bone("bip01 r hand")
		var weapon := rig.find_bone("lizardman weapon")
		var mesh := visual.model.find_children("Spear" if body == 35 else "Mace", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh, rig)
		var rest := rig.get_bone_rest(weapon)
		var grip := {}
		player.play("Idle", 0.0)
		player.advance(0.0)
		for label: String in ["finger0", "finger01", "finger1", "finger11"]:
			var bone := rig.find_bone("bip01 r " + label)
			assert(bone >= 0)
			grip[bone] = rig.get_bone_pose_rotation(bone)
		for slot: int in SLOTS:
			var packet := PackedByteArray([0x6e])
			packet.append_array(Wire.uint_be(SERIAL, 4))
			packet.append_array(PackedByteArray([0, slot, 0, (5 if slot in [17, 18] else (3 if slot in [15,16] else 4)), 0, 1, 1, 0, 0]))
			game._handle(packet)
			visual.dead = false
			player.stop()
			assert(visual.receive_action(game.last_mobile_actions[SERIAL]) and visual.current_clip == SLOTS[slot])
			player.advance(0.0)
			var start := Vector3.ZERO
			var min_floor := INF
			var x_min := INF
			var initial_axis := Vector3.ZERO
			for i in 61:
				player.seek(player.current_animation_length * i / 60.0, true)
				rig.force_update_all_bone_transforms()
				var hilt := rig.get_bone_global_pose(hand)
				var shaft := rig.get_bone_global_pose(weapon)
				if slot != 3:
					assert((hilt.inverse() * shaft).is_equal_approx(rest))
					for bone: int in grip:
						assert(rig.get_bone_pose_rotation(bone).angle_to(grip[bone]) < 0.002)
				assert(visual.global_transform == anchor and visual.native_hue == 0x8035)
				min_floor = minf(min_floor, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
				var point := rig.to_global(hilt.origin)
				if i == 0:
					start = point
					initial_axis = (rig.global_basis * shaft.basis.y).normalized()
				x_min = minf(x_min, point.x)
				count += 1
			if slot in [2, 3]:
				var front := rig.to_global(rig.get_bone_global_pose(head).origin) - rig.to_global(rig.get_bone_global_pose(hip).origin)
				assert(front.z < -0.45 if slot == 2 else front.z > 0.45)
				print(body, " ", slot, " collapse heading ", front.z)
			assert(min_floor >= 0.0, "The armed animation penetrated the nominal flat floor")
			print(body, " ", slot, " shaft initial ", initial_axis, " hilt ", start, " sweep min x ", x_min, " floor ", min_floor)
		visual.free()
	game.free()
	print("LIZARD ACTIONS: ", count, " decoded armed poses with unchanged hilt bind and previous keys")
	quit()

static func trial_row(body: int) -> Dictionary:
	var row: Dictionary
	if "--active" in OS.get_cmdline_user_args():
		row = Registry.entry(body)
		assert(row.classic_gesture_batch == "lizard_actions")
	else:
		var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/lizard_actions/candidates.json"))
		var matching := candidates.filter(func(candidate: Dictionary) -> bool: return int(candidate.body) == body)
		assert(matching.size() == 1)
		row = matching[0].presentation
	assert(FileAccess.get_sha256(row.assets.modern) == row.authored_action_scene_sha256.modern)
	assert(FileAccess.get_sha256(row.presentation_script) == row.presentation_script_sha256)
	return row
