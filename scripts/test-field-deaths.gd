extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Corpse := preload("res://Presentation/CorpseModels.gd")
const SERIAL := 0x4711

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var count := 0
	var active := "--active" in OS.get_cmdline_user_args()
	var bundle := "res://../work/creatures/field_deaths/"
	if active:
		bundle += "accepted-native/"
	var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string(bundle + "candidates.json"))
	for body: int in [237, 238]:
		var base := Registry.entry(body)
		var rows := candidates.filter(func(item: Dictionary) -> bool: return int(item.body) == body)
		assert(not rows.is_empty())
		var row: Dictionary = rows[0].presentation
		for candidate: Dictionary in rows:
			assert(candidate.presentation == row)
		var base_assets: Dictionary = base.assets
		if active and body == 237:
			assert(base.classic_gesture_batch == "field_deaths")
			base_assets = base.classic_gesture_base_assets
			row = base
		elif active and base.classic_action_categories.has("12"):
			base_assets = {"modern": "res://Art/Creatures/Rat/rat-fidgets.scn"}
			assert(FileAccess.get_sha256(base.assets.modern) == row.authored_action_scene_sha256.modern)
			row = dict_with_pose_pins(base, row)
		assert(FileAccess.get_sha256(row.presentation_script) == row.collapse_renderer_sha256)
		Registry.entries[body] = row
		game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0x489}
		for treatment: String in base_assets:
			assert(FileAccess.get_sha256(row.assets[treatment]) == row.authored_action_scene_sha256[treatment])
			var visual := Registry.create(body)
			visual.treatment = treatment
			root.add_child(visual)
			visual.apply_identity(body, 0x489)
			visual.set_process(false)
			visual.set_physics_process(false)
			var player: AnimationPlayer = visual.animator
			check_earlier_keys(player, base_assets[treatment])
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var rig: Skeleton3D = visual.skeleton
			var hip := rig.find_bone("bip01 pelvis" if body == 237 else "base")
			var head := rig.find_bone("bip01 head" if body == 237 else "head")
			var mesh := visual.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var skin := Ground.skin_points(mesh, rig)
			var anchor := visual.global_transform
			var surface := StaticBody3D.new()
			root.add_child(surface)
			var box := BoxShape3D.new()
			box.size = Vector3(7.0, 0.16, 7.0)
			var collider := CollisionShape3D.new()
			collider.shape = box
			surface.add_child(collider)
			collider.position.y = -0.08
			for slope: Vector3 in [Vector3.ZERO, Vector3(0.18, 0.0, 0.11), Vector3(-0.13, 0.0, -0.15)]:
				surface.rotation = slope
				await physics_frame
				await physics_frame
				for slot: int in [8, 12]:
					visual.dead = false
					visual.contact.enabled = true
					visual.contact.sample(surface.get_world_3d().direct_space_state, visual.global_position)
					assert(not visual.contact.contacts.is_empty())
					var hit: Dictionary = visual.contact.contacts.values()[0]
					player.stop()
					var packet := PackedByteArray([0x6e])
					packet.append_array(Wire.uint_be(SERIAL, 4))
					packet.append_array(PackedByteArray([0, slot, 0, 6, 0, 1, 1, 0, 0]))
					game._handle(packet)
					assert(visual.receive_action(game.last_mobile_actions[SERIAL]) and visual.current_clip == row.classic_action_categories[str(slot)])
					player.advance(0.0)
					var max_tilt := -INF
					var min_floor := INF
					for sample in 65:
						player.seek(player.current_animation_length * sample / 64.0, true)
						rig.force_update_all_bone_transforms()
						var forward := rig.to_global(rig.get_bone_global_pose(head).origin) - rig.to_global(rig.get_bone_global_pose(hip).origin)
						max_tilt = maxf(max_tilt, forward.normalized().y)
						var floor := Ground.minimum_plane_gap(skin, rig, rig.global_transform, hit.position, hit.normal)
						min_floor = minf(floor, min_floor)
						assert(floor >= -0.001)
						if sample == 64:
							assert(absf(floor - 0.002) < 0.001)
						assert(is_finite(floor) and visual.global_transform == anchor and visual.native_hue == 0x489)
						count += 1
					print(body, " ", treatment, " slot ", slot, " high tilt ", max_tilt, " floor ", min_floor)
			surface.free()
			visual.free()
		for hue: int in [0, 0x489, 0x8035]:
			var corpse := Corpse.build(body, hue)
			assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("native_hue") == hue)
			corpse.free()
	game.free()
	print("FIELD DEATH TRIAL: ", count, " decoded flat and finite slope poses, retained static corpse body and hue")
	quit()

func dict_with_pose_pins(row: Dictionary, tested: Dictionary) -> Dictionary:
	assert(row.classic_action_categories == tested.classic_action_categories)
	var pinned := row.duplicate()
	pinned.authored_action_scene_sha256 = tested.authored_action_scene_sha256
	return pinned

func check_earlier_keys(player: AnimationPlayer, source: String) -> void:
	var prior := (load(source) as PackedScene).instantiate()
	var reference := prior.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for label: String in reference.get_animation_list():
		var before := reference.get_animation(label)
		var after := player.get_animation(label)
		assert(before.length == after.length and before.get_track_count() == after.get_track_count())
		for track in before.get_track_count():
			assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track))
	prior.free()
