extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Deaths := preload("res://Presentation/CreatureDeaths.gd")
const Items := preload("res://Presentation/WorldItems.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const CANDIDATES := "res://../work/creatures/daemon_wyvern_polar_actions/candidates.json"

class Arena extends Node3D:
	var avatars: Dictionary = {}

class Avatar extends Node3D:
	var horse_visual: Node3D

func _initialize() -> void:
	create_timer(100.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATES))
		assert(rows.size() == 3)
		for row: Dictionary in rows:
			Registry.entries[int(row.body)] = row.presentation
	for tilt: Vector3 in [Vector3.ZERO, Vector3(0.14, 0.0, 0.11), Vector3(-0.12, 0.0, -0.10)]:
		for body: int in [9, 62]:
			await witness(body, tilt, 0, 0.0)
			await witness(body, tilt, 3, 0.43)
			await witness(body, tilt, 21, 0.07)
			await witness(body, tilt, 21, 0.43)
			await witness(body, tilt, -1, 0.0)
		await witness(213, tilt, 0, 0.0)
		await witness(213, tilt, 12, 0.07)
		await witness(213, tilt, 12, 0.43)
	print("CREATURE CORPSES: 39 decoded handoffs across 1599 terrain samples")
	quit()

func witness(body: int, tilt: Vector3, slot: int, phase: float) -> void:
	var continuing := phase > 0.0
	var flying := slot in [-1, 21]
	var clip := "AirDeath" if flying else ("Death2" if slot in [3, 12] else "Death")
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var arena := Arena.new()
	root.add_child(arena)
	var items := Items.new()
	arena.add_child(items)
	items.add_child(items.hint)
	items.session = game
	var deaths := Deaths.new()
	arena.add_child(deaths)
	deaths.configure(arena, game, items)
	deaths.set_process(false)
	var ground := StaticBody3D.new()
	arena.add_child(ground)
	ground.rotation = tilt
	var box := BoxShape3D.new()
	var ground_width := 32.0 if body in [9, 62] else 8.0
	box.size = Vector3(ground_width, 0.10, ground_width)
	var collider := CollisionShape3D.new()
	collider.shape = box
	collider.position.y = -0.05
	ground.add_child(collider)
	await physics_frame
	await physics_frame
	var killed := 10000 + body
	var serial := 0x40010000 + body
	var avatar := Avatar.new()
	arena.add_child(avatar)
	avatar.horse_visual = Registry.create(body)
	avatar.add_child(avatar.horse_visual)
	avatar.horse_visual.apply_identity(body, 0x8035)
	avatar.horse_visual.contact.sample(ground.get_world_3d().direct_space_state, avatar.global_position)
	arena.avatars[killed] = avatar
	game.entities[killed] = {"serial": killed, "body": body, "hue": 0x8035, "direction": 4}
	var displayed_phase := 0.0
	var displayed_speed := 1.0
	var displayed_pose: Array[Transform3D] = []
	var living: Node3D = avatar.horse_visual
	var source_player: AnimationPlayer = living.animator
	source_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if flying:
		living.current_clip = "Fly"
		source_player.play("Fly", 0.0)
		source_player.advance(0.0)
		source_player.seek(source_player.current_animation_length * 0.23, true)
	if continuing:
		var action := PackedByteArray([0x6e])
		action.append_array(Wire.uint_be(killed, 4))
		action.append_array(PackedByteArray([0, slot, 0, 5, 0, 1, 1, 0, 0]))
		game._handle(action)
		assert(living.receive_action(game.last_mobile_actions[killed]) and living.current_clip == clip)
		source_player.advance(0.025 if phase < 0.1 else 0.13)
		displayed_phase = source_player.current_animation_length * phase
		source_player.seek(displayed_phase, true)
		displayed_speed = source_player.get_playing_speed()
	if continuing or flying:
		for bone in living.skeleton.get_bone_count():
			displayed_pose.append(living.skeleton.get_bone_pose(bone))
	var holder := Node3D.new()
	items.add_child(holder)
	items.nodes[serial] = holder
	assert(items._equine_corpse(holder, {"id": 0x2006, "amount": body, "hue": 0x8035, "direction": 4}, serial))
	var packet := PackedByteArray([0xaf])
	packet.append_array(Wire.uint_be(killed, 4))
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(Wire.uint_be(0, 4))
	game._handle(packet)
	assert(deaths.active.has(killed) and not holder.visible and not avatar.visible)
	var visual: Node3D = deaths.active[killed].visual
	var rig: Skeleton3D = visual.skeleton
	var player: AnimationPlayer = visual.animator
	var anchor := visual.global_transform
	var plane: Dictionary = visual.collapse_plane
	assert(plane.collider == ground, "Body %d, tilt %s, phase %.2f sampled %s" % [body, tilt, phase, plane])
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	assert(visual.current_clip == clip)
	if continuing:
		assert(is_equal_approx(player.current_animation_position, displayed_phase))
		assert(is_equal_approx(player.get_playing_speed(), displayed_speed))
		assert(is_equal_approx(visual.action_remaining,
			(player.current_animation_length - displayed_phase) / displayed_speed))
	if continuing or flying:
		for bone in displayed_pose.size():
			assert(rig.get_bone_pose(bone).is_equal_approx(displayed_pose[bone]))
	else:
		player.play(clip, 0.0)
		player.advance(0.0)
	for frame in 41:
		player.seek(lerpf(displayed_phase, player.current_animation_length, frame / 40.0), true)
		var gap := Ground.minimum_plane_gap(visual.collapse_skin, rig, rig.global_transform, plane.position, plane.normal)
		assert(is_finite(gap) and gap > -0.001 and visual.global_transform == anchor)
	var removal := PackedByteArray([0x1d])
	removal.append_array(Wire.uint_be(killed, 4))
	game._handle(removal)
	arena.avatars.erase(killed)
	avatar.free()
	deaths._process(float(deaths.active[killed].remaining) + 0.1)
	assert(holder.visible and deaths.active.is_empty() and items.corpse_snapshots.has(serial))
	var cadaver := holder.get_node("CorpseVisual") as Node3D
	assert(cadaver.get_meta("corpse_body") == body and cadaver.get_meta("native_hue") == 0x8035)
	assert(cadaver.get_meta("death_clip") == clip)
	assert(cadaver.get_meta("static_cadaver") and cadaver.find_children("*", "Skeleton3D", true, false).is_empty())
	var least := INF
	assert(not cadaver.find_children("*", "MeshInstance3D", true, false).is_empty())
	for mesh: MeshInstance3D in cadaver.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var points: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point: Vector3 in points:
				least = minf(least, (mesh.to_global(point) - plane.position).dot(plane.normal))
	assert(least > -0.001 and least < 0.005,
		"Body %d, tilt %s, phase %.2f froze with clearance %.5f" % [body, tilt, phase, least])
	arena.free()
	game.free()
