extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Corpse := preload("res://Presentation/CorpseModels.gd")
const SERIAL := 0x4938
const SLOTS := {4: "LookSide", 5: "Attack", 6: "Attack2", 8: "Death", 9: "Fidget", 10: "Fidget2", 12: "Death2"}
const FRAMES := {4: 3, 5: 5, 6: 5, 8: 6, 9: 5, 10: 3, 12: 6}

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var samples := 0
	for body: int in trial_bodies():
		var base := Registry.entry(body)
		var row := trial_row(body)
		game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0x489}
		Registry.entries[body] = row
		for treatment: String in row.assets:
			var visual := Registry.create(body)
			visual.treatment = treatment
			root.add_child(visual)
			visual.apply_identity(body, 0x489)
			visual.set_process(false)
			visual.set_physics_process(false)
			var player: AnimationPlayer = visual.animator
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var source: String = base.classic_gesture_base_assets[treatment] if base.has("classic_gesture_base_assets") else Registry.asset_path(base, treatment)
			check_earlier_keys(player, source)
			var rig: Skeleton3D = visual.skeleton
			var pelvis := rig.find_bone("bip01 pelvis")
			var head := rig.find_bone("bip01 head")
			var skin := Ground.skin_points(visual.model.find_children("*", "MeshInstance3D", true, false)[0], rig)
			var anchor := visual.global_transform
			var surface := StaticBody3D.new()
			root.add_child(surface)
			var box := BoxShape3D.new()
			box.size = Vector3(7.0, 0.16, 7.0)
			var collider := CollisionShape3D.new()
			collider.shape = box
			surface.add_child(collider)
			collider.position.y = -0.08
			var curves := {}
			for slope: Vector3 in [Vector3.ZERO, Vector3(0.14, 0.0, 0.11), Vector3(-0.12, 0.0, -0.10)]:
				surface.rotation = slope
				await physics_frame
				await physics_frame
				var groups: Array = [8, 12] if body == 234 or slope != Vector3.ZERO else row.classic_action_categories.keys().map(func(slot: String) -> int: return int(slot))
				for slot: int in groups:
					visual.dead = false
					visual.contact.enabled = true
					visual.contact.sample(surface.get_world_3d().direct_space_state, visual.global_position)
					assert(not visual.contact.contacts.is_empty())
					var hit: Dictionary = visual.contact.contacts.values()[0]
					player.stop()
					var packet := PackedByteArray([0x6e])
					packet.append_array(Wire.uint_be(SERIAL, 4))
					packet.append_array(PackedByteArray([0, slot, 0, FRAMES[slot], 0, 1, 1, 0, 0]))
					game._handle(packet)
					assert(visual.receive_action(game.last_mobile_actions[SERIAL]) and visual.current_clip == SLOTS[slot])
					player.advance(0.0)
					var curve := PackedVector3Array()
					var least := INF
					for frame in 49:
						player.seek(player.current_animation_length * frame / 48.0, true)
						rig.force_update_all_bone_transforms()
						var centre := rig.to_global(rig.get_bone_global_pose(pelvis).origin)
						curve.append(rig.to_global(rig.get_bone_global_pose(head).origin) - centre)
						var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, hit.position, hit.normal)
						assert(is_finite(gap) and visual.global_transform == anchor and visual.native_hue == 0x489)
						if slot in [8, 12]:
							assert(gap > -0.001)
							if frame == 48:
								assert(absf(gap - 0.002) < 0.001)
						least = minf(least, gap)
						samples += 1
					if slope == Vector3.ZERO:
						curves[slot] = curve
						print(body, " ", treatment, " slot ", slot, " floor ", least, " apex ", curve[24], " end ", curve[48])
			for pair: Array in ([[8, 12]] if body == 234 else [[5, 6], [8, 12], [9, 10]]):
				assert(curves[pair[0]] != curves[pair[1]])
			surface.free()
			visual.free()
		for hue: int in [0, 0x489, 0x8035]:
			var corpse := Corpse.build(body, hue)
			assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("native_hue") == hue)
			corpse.free()
	game.free()
	print("QUADRUPEDS: ", samples, " decoded poses, retained source keys, static corpse hues")
	quit()

static func trial_row(body: int) -> Dictionary:
	var row: Dictionary
	var family := "hart_deaths" if body == 234 else "quadruped_actions"
	if "--active" in OS.get_cmdline_user_args():
		row = Registry.entry(body)
		assert(row.classic_gesture_batch == family)
	else:
		var path := "res://../work/creatures/%s/candidates.json" % family
		var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		var matching := candidates.filter(func(candidate: Dictionary) -> bool: return int(candidate.body) == body)
		assert(not matching.is_empty())
		row = matching[0].presentation
		assert(matching.all(func(candidate: Dictionary) -> bool: return candidate.presentation == row))
	for treatment: String in row.assets:
		assert(FileAccess.get_sha256(row.assets[treatment]) == row.authored_action_scene_sha256[treatment])
	assert(FileAccess.get_sha256(row.presentation_script) == row.presentation_script_sha256)
	return row

static func trial_bodies() -> Array[int]:
	return [234] if "--hart" in OS.get_cmdline_user_args() else [225, 207, 223]

static func check_earlier_keys(player: AnimationPlayer, source: String) -> void:
	var prior := (load(source) as PackedScene).instantiate()
	var reference := prior.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for label: String in reference.get_animation_list():
		var before := reference.get_animation(label)
		var after := player.get_animation("RecoveredDeath" if label == "Death" else label)
		assert(before.length == after.length and before.get_track_count() == after.get_track_count())
		for track in before.get_track_count():
			assert(before.track_get_path(track) == after.track_get_path(track))
			assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track))
	prior.free()
