extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Corpse := preload("res://Presentation/CorpseModels.gd")
const SERIAL := 0x4115
const SLOTS := {4: "Attack", 5: "Attack2", 6: "Attack3", 10: "Hit", 15: "BoneInward", 16: "BoneWide", 17: "BoneStretch", 18: "Fidget2"}

func _initialize() -> void:
	create_timer(24.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var samples := 0
	for body: int in [50, 56]:
		var base := Registry.entry(body)
		var row := trial_row(body)
		Registry.entries[body] = row
		game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0x8035}
		var previous_assets: Dictionary = base.classic_gesture_base_assets if base.get("classic_gesture_batch") == "skeleton_actions" else base.assets
		for treatment: String in row.assets:
			var path: String = previous_assets[treatment]
			var visual := Registry.create(body)
			visual.treatment = treatment
			root.add_child(visual)
			visual.apply_identity(body, 0x8035)
			visual.set_process(false)
			visual.set_physics_process(false)
			var player: AnimationPlayer = visual.animator
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var rig: Skeleton3D = visual.skeleton
			var prior := (load(path) as PackedScene).instantiate()
			var source_player := prior.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			for clip: String in source_player.get_animation_list():
				var previous := source_player.get_animation(clip)
				var current := player.get_animation(clip)
				assert(previous.length == current.length and previous.get_track_count() == current.get_track_count(),
					"Body %d treatment %s retained clip %s differs from %s" % [body, treatment, clip, path])
				for track in previous.get_track_count():
					assert(previous.get("tracks/%d/keys" % track) == current.get("tracks/%d/keys" % track))
			prior.free()
			var anchor := visual.global_transform
			var pelvis := rig.find_bone("bip01 pelvis")
			var right := rig.find_bone("bip01 r hand")
			var left := rig.find_bone("bip01 l hand")
			var grip := rig.find_bone("cp_grasp_rhand")
			var axe := rig.find_bone("skeleton axe")
			var meshes: Array[Dictionary] = []
			for mesh: MeshInstance3D in visual.model.find_children("*", "MeshInstance3D", true, false):
				if mesh.skin != null:
					meshes.append(Ground.skin_points(mesh, rig))
			var curves := {}
			for slot: int in SLOTS:
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(SERIAL, 4))
				packet.append_array(PackedByteArray([0, slot, 0, 3 if slot in [15, 16] else 4, 0, 1, 1, 0, 0]))
				game._handle(packet)
				player.stop()
				assert(visual.receive_action(game.last_mobile_actions[SERIAL]) and visual.current_clip == SLOTS[slot])
				player.advance(0.0)
				var floor := INF
				var curve := PackedVector3Array()
				for frame in 61:
					player.seek(player.current_animation_length * frame / 60.0, true)
					rig.force_update_all_bone_transforms()
					var hip := rig.to_global(rig.get_bone_global_pose(pelvis).origin)
					curve.append(rig.to_global(rig.get_bone_global_pose(right).origin) - hip)
					curve.append(rig.to_global(rig.get_bone_global_pose(left).origin) - hip)
					if axe >= 0:
						var fit := rig.get_bone_global_pose(grip).inverse() * rig.get_bone_global_pose(axe)
						assert(fit.is_equal_approx(rig.get_bone_rest(axe)))
					assert(visual.global_transform == anchor and visual.native_hue == 0x8035)
					for skin: Dictionary in meshes:
						floor = minf(floor, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
					samples += 1
				assert(is_finite(floor) and floor > (-0.019 if slot in [4, 10] else -0.001))
				print(body, " ", slot, " least skinned floor ", floor)
				curves[slot] = curve
			for pair: Array in [[4, 5], [4, 6], [5, 6], [10, 15], [10, 16], [15, 16], [17, 18]]:
				var divergence := 0.0
				for index in curves[pair[0]].size():
					divergence = maxf(divergence, curves[pair[0]][index].distance_to(curves[pair[1]][index]))
				assert(divergence > 0.15)
			if body == 50:
				var reach := PackedByteArray([0xe2])
				reach.append_array(Wire.uint_be(SERIAL, 4))
				reach.append_array(PackedByteArray([0, 14, 0, 0, 0]))
				game._handle(reach)
				assert(visual.receive_action(game.last_mobile_actions[SERIAL]) and visual.current_clip == "Reach")
			visual.free()
		for hue: int in [0, 53, 0x8035]:
			var body_mesh := Corpse.build(body, hue)
			assert(body_mesh != null and body_mesh.get_meta("static_cadaver") and body_mesh.get_meta("native_hue") == hue)
			assert((body_mesh.find_child("SkeletonAxe", true, false) != null) == (body == 56))
			body_mesh.free()
	game.free()
	print("SKELETON ACTIONS: ", samples, " decoded poses, rigid axe and six corpse hue checks")
	quit()

static func trial_row(body: int) -> Dictionary:
	var row: Dictionary
	if "--active" in OS.get_cmdline_user_args():
		row = Registry.entry(body)
		assert(row.classic_gesture_batch == "skeleton_actions")
	else:
		var path := "res://../work/creatures/skeleton_actions/candidates.json"
		var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		var matching := candidates.filter(func(candidate: Dictionary) -> bool: return int(candidate.body) == body)
		assert(matching.size() == 1)
		row = matching[0].presentation
	for treatment: String in row.assets:
		assert(FileAccess.get_sha256(row.assets[treatment]) == row.authored_action_scene_sha256[treatment])
	return row
