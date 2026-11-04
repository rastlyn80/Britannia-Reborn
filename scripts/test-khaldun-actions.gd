extends "res://../scripts/test-spider-mongbat-gestures.gd"

const PACKAGE := "res://local-art/creatures/khaldun_actions/preparation.json"
const GHOST_PACKAGE := "res://local-art/creatures/restless_soul_actions/preparation.json"
const BASE := "res://local-art/creatures/khaldun_doom/preparation.json"
const CorpseModels := preload("res://Presentation/CorpseModels.gd")
const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Deaths := preload("res://Presentation/CreatureDeaths.gd")

class DeathArena extends Node3D:
	var avatars: Dictionary = {}

class DeathItems extends Node:
	var nodes: Dictionary = {}

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var active_body := 637 if "--active-spectral" in args else 970 if "--active-ghost" in args else 0
	var package := GHOST_PACKAGE if "--ghost-prepared" in args else PACKAGE
	var rows: Array = [Registry.entry(active_body)] if active_body else JSON.parse_string(FileAccess.get_file_as_string(package)).models
	var baselines: Array = JSON.parse_string(FileAccess.get_file_as_string(BASE)).models
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var poses := 0
	var preserved := 0
	var death_cases := 0
	for index in rows.size():
		var row: Dictionary = rows[index]
		var body := int(row.bodies[0].body)
		var hue := int(row.native_constructor_hues.values()[0])
		if active_body:
			var family := "khaldun_actions" if active_body == 637 else "restless_soul_actions"
			var layered_mount: bool = active_body == 970 and row.family == "restless_soul_mounted" and row.has("restless_soul_mount_sha256")
			assert(body == active_body and row.status == "validated" and (row.family == family or layered_mount))
		else:
			Registry.entry(body)
			Registry.entries[body] = row
		game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": hue, "direction": 4}
		var minimum := INF
		for treatment: String in row.assets:
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body, hue)
			actor.set_process(false)
			actor.set_physics_process(false)
			assert(actor.native_body == body and actor.native_hue == hue)
			var rig: Skeleton3D = actor.skeleton
			var player: AnimationPlayer = actor.animator
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var predecessor: Dictionary = baselines[0 if body == 637 else 1]
			var base := (load(predecessor.assets[treatment]) as PackedScene).instantiate()
			var base_player := base.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var staged := (load(row.assets[treatment]) as PackedScene).instantiate()
			var staged_player := staged.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			for clip: String in base_player.get_animation_list():
				assert(equal_clip(base_player.get_animation(clip), staged_player.get_animation(clip)), "%d %s %s" % [body, treatment, clip])
				preserved += 1
			base.free()
			staged.free()
			var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var skin := Ground.skin_points(mesh, rig)
			var anchor := actor.global_transform
			for group: String in row.action_witness_frames:
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(SERIAL, 4))
				packet.append_array(PackedByteArray([0, int(group), 0, int(row.action_witness_frames[group]), 0, 1, 1, 0, 0]))
				game._handle(packet)
				player.stop()
				actor.dead = false
				assert(actor.receive_action(game.last_mobile_actions[SERIAL]))
				assert(actor.current_clip == row.classic_action_categories[group])
				var duration: float = actor.action_remaining
				var clip_floor := INF
				for frame in 49:
					player.advance(0.0 if frame == 0 else duration / 48.0)
					rig.force_update_all_bone_transforms()
					var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
					assert(is_finite(gap) and actor.global_transform == anchor)
					minimum = minf(gap, minimum)
					clip_floor = minf(gap, clip_floor)
					poses += 1
				if clip_floor < -0.012:
					print("KHALDUN BELOW FLOOR ", body, " ", treatment, " ", group, " ", clip_floor)
			actor.free()
		for corpse_hue: int in [0, hue, 0x48e]:
			var corpse := CorpseModels.build(body, corpse_hue)
			assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("native_hue") == corpse_hue)
			assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			corpse.free()
		for slope: Vector3 in [Vector3.ZERO, Vector3(0.19, 0.0, 0.11), Vector3(-0.16, 0.0, -0.18)]:
			if not await check_death_transition(game, body, hue, slope):
				quit(1)
				return
			death_cases += 1
		print("KHALDUN BODY ", body, " floor minimum ", minimum)
		assert(minimum >= (-0.012 if body == 970 else 0.0))
	game.free()
	print("KHALDUN ROUTES PASS: ", poses, " decoded skin poses / ", preserved, " preserved named clips / ", death_cases, " finite terrain death cases")
	quit()

func check_death_transition(game: Node, body: int, hue: int, slope: Vector3) -> bool:
	var arena := DeathArena.new()
	var items := DeathItems.new()
	var deaths := Deaths.new()
	root.add_child(arena)
	arena.add_child(items)
	arena.add_child(deaths)
	deaths.configure(arena, game, items)
	deaths.set_process(false)
	var avatar := Avatar.new()
	avatar.initial_body = body
	arena.add_child(avatar)
	avatar.set_physics_process(false)
	avatar.apply_server_appearance(game.entities[SERIAL], [])
	arena.avatars[SERIAL] = avatar
	var terrain := StaticBody3D.new()
	arena.add_child(terrain)
	terrain.rotation = slope
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8.0, 0.15, 8.0)
	collider.shape = shape
	terrain.add_child(collider)
	collider.position.y = -shape.size.y * 0.5
	await physics_frame
	await physics_frame
	var source: Node3D = avatar.horse_visual
	source.global_rotation.y = PI - float(int(game.entities[SERIAL].direction) & 7) * PI / 4.0
	source.contact.sample(arena.get_world_3d().direct_space_state, source.global_position)
	var hit: Dictionary = source.contact.contacts[0]
	assert(hit.collider == terrain)
	source.support_control_plane()
	var corpse := 0 if body == 637 else 0x40004100
	if corpse:
		var item := Node3D.new()
		arena.add_child(item)
		items.nodes[corpse] = item
	var packet := PackedByteArray([0xaf])
	packet.append_array(Wire.uint_be(SERIAL, 4))
	packet.append_array(Wire.uint_be(corpse, 4))
	packet.append_array(PackedByteArray([0, 0, 0, 0]))
	game._handle(packet)
	assert(deaths.active.has(SERIAL) and not avatar.visible)
	var visual: Node3D = deaths.active[SERIAL].visual
	assert(visual.native_body == body and visual.native_hue == hue and visual.current_clip == "Death")
	assert(deaths.held_corpses.has(corpse) == (corpse != 0))
	if corpse:
		assert(not items.nodes[corpse].visible)
	var player: AnimationPlayer = visual.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var rig: Skeleton3D = visual.skeleton
	var mesh := visual.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var step: float = player.current_animation_length / 48.0
	var minimum := INF
	var worst := -1
	for sample in 49:
		player.advance(0.0 if sample == 0 else step)
		rig.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, hit.position, hit.normal)
		if gap < minimum:
			worst = sample
			minimum = gap
	deaths.finish(SERIAL)
	assert(avatar.visible and deaths.held_corpses.is_empty() and deaths.active.is_empty())
	if corpse:
		assert(items.nodes[corpse].visible)
	if body == 637:
		var anchor := source.global_transform
		packet = PackedByteArray([0x6e])
		packet.append_array(Wire.uint_be(SERIAL, 4))
		packet.append_array(PackedByteArray([0, 22, 0, 6, 0, 1, 1, 0, 0]))
		game._handle(packet)
		player = source.animator
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.stop()
		assert(avatar.receive_native_action(game.last_mobile_actions[SERIAL]) and source.current_clip == "Death2")
		rig = source.skeleton
		skin = source.control_skin
		step = source.action_remaining / 48.0
		for sample in 49:
			player.advance(0.0 if sample == 0 else step)
			rig.force_update_all_bone_transforms()
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, hit.position, hit.normal)
			assert(is_finite(gap) and source.global_transform == anchor)
			if gap < minimum:
				worst = sample
				minimum = gap
	arena.free()
	if not is_finite(minimum) or minimum < -0.012:
		push_error("Body %d slope %s death minimum %.5f at sample %d" % [body, slope, minimum, worst])
		return false
	return true

func equal_clip(a: Animation, b: Animation) -> bool:
	if b == null or a.length != b.length or a.loop_mode != b.loop_mode or a.get_track_count() != b.get_track_count():
		print("clip metadata ", a.length, " ", b.length, " / ", a.loop_mode, " ", b.loop_mode, " / ", a.get_track_count(), " ", b.get_track_count())
		return false
	for track in a.get_track_count():
		if a.track_get_path(track) != b.track_get_path(track) or a.track_get_type(track) != b.track_get_type(track) \
				or a.track_get_key_count(track) != b.track_get_key_count(track):
			print("track metadata ", a.track_get_path(track), " ", b.track_get_path(track))
			return false
		for key in a.track_get_key_count(track):
			if a.track_get_key_time(track, key) != b.track_get_key_time(track, key) \
					or a.track_get_key_value(track, key) != b.track_get_key_value(track, key):
				print("key ", track, " ", key, " ", a.track_get_key_time(track, key), " ", b.track_get_key_time(track, key), " ", a.track_get_key_value(track, key), " ", b.track_get_key_value(track, key))
				return false
	return true
