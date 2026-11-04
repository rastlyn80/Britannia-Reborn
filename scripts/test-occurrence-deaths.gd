extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Corpse := preload("res://Presentation/CorpseModels.gd")
const SERIAL := 0x4135

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var count := 0
	var active := "--active" in OS.get_cmdline_user_args()
	var candidates: Array = []
	if not active:
		candidates = JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/occurrence_deaths/candidates.json"))
	for body: int in [17, 18]:
		var row := Registry.entry(body)
		var base_paths: Dictionary = row.assets
		if active:
			assert(row.classic_gesture_batch == "occurrence_deaths")
			base_paths = row.classic_gesture_base_assets
		else:
			var matches := candidates.filter(func(item: Dictionary) -> bool: return int(item.body) == body)
			assert(matches.size() == 1)
			row = matches[0].presentation
			Registry.entries[body] = row
		assert(row.classic_action_categories["2"] == "Death2" and row.classic_action_categories["3"] == "Death")
		game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0x489}
		for treatment: String in row.assets:
			assert(FileAccess.get_sha256(row.assets[treatment]) == row.authored_action_scene_sha256[treatment])
			var visual := Registry.create(body)
			visual.treatment = treatment
			root.add_child(visual)
			visual.apply_identity(body, 0x489)
			visual.set_process(false)
			visual.set_physics_process(false)
			var base := (load(base_paths[treatment]) as PackedScene).instantiate()
			var previous := base.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var player: AnimationPlayer = visual.animator
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			for label: String in previous.get_animation_list():
				var before := previous.get_animation(label)
				var after := player.get_animation(label)
				assert(before.length == after.length and before.get_track_count() == after.get_track_count())
				for track in before.get_track_count():
					assert(before.track_get_key_count(track) == after.track_get_key_count(track))
					for key in before.track_get_key_count(track):
						assert(before.track_get_key_time(track, key) == after.track_get_key_time(track, key))
						assert(before.track_get_key_value(track, key) == after.track_get_key_value(track, key))
			base.free()
			var rig: Skeleton3D = visual.skeleton
			var head := rig.find_bone("bip01 head" if body == 17 else "geosphere01")
			var hip := rig.find_bone("bip01 pelvis")
			var mesh := visual.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var skin := Ground.skin_points(mesh, rig)
			var transform := visual.global_transform
			var ground := StaticBody3D.new()
			root.add_child(ground)
			var collider := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(9.0, 0.15, 9.0)
			collider.shape = box
			ground.add_child(collider)
			collider.position.y = -box.size.y * 0.5
			for slope: Vector3 in [Vector3.ZERO, Vector3(0.18, 0.0, 0.11), Vector3(-0.13, 0.0, -0.15)]:
				ground.rotation = slope
				await physics_frame
				await physics_frame
				for slot: int in [2, 3]:
					visual.dead = false
					visual.contact.enabled = true
					visual.contact.sample(ground.get_world_3d().direct_space_state, visual.global_position)
					var hit: Dictionary = visual.contact.contacts.values()[0]
					assert(hit.collider == ground)
					count += play_death(game, visual, player, rig, skin, row, slot, hit, transform, head, hip)
			ground.free()
			visual.free()
		for hue: int in [0, 0x489, 0x8035]:
			var corpse := Corpse.build(body, hue)
			assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("native_hue") == hue)
			assert(corpse.get_meta("death_clip") == "Death" and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			corpse.free()
	game.free()
	print("OCCURRENCE DEATH PREVIEW PASS: ", count, " sampled poses for both collapses on flat terrain and two slopes")
	quit()

func play_death(game: Node, visual: Node3D, player: AnimationPlayer, rig: Skeleton3D,
		skin: Dictionary, row: Dictionary, slot: int, hit: Dictionary, anchor: Transform3D, head: int, hip: int) -> int:
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(SERIAL, 4))
	packet.append_array(PackedByteArray([0, slot, 0, 4, 0, 1, 1, 0, 0]))
	game._handle(packet)
	player.stop()
	assert(visual.receive_action(game.last_mobile_actions[SERIAL]))
	assert(visual.current_clip == row.classic_action_categories[str(slot)] and visual.dead)
	player.advance(0.0)
	var floor := INF
	var worst := -1
	for frame in 49:
		player.seek(player.current_animation_length * float(frame) / 48.0, true)
		rig.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, hit.position, hit.normal)
		assert(is_finite(gap) and visual.global_transform == anchor)
		if frame == 48:
			assert(absf(gap - 0.002) < 0.001, "Finished collapse must settle against the last support plane")
		if gap < floor:
			floor = gap
			worst = frame
	var landing := rig.to_global(rig.get_bone_global_pose(head).origin) - rig.to_global(rig.get_bone_global_pose(hip).origin)
	assert(landing.z < -0.45 if slot == 2 else landing.z > 0.45)
	assert(floor >= -0.002, "%s slot %d floor %f at %d" % [visual.kind, slot, floor, worst])
	print(visual.native_body, " ", visual.treatment, " slot ", slot, " floor ", floor)
	return 49
