extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Deaths := preload("res://Presentation/CreatureDeaths.gd")
const Items := preload("res://Presentation/WorldItems.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const CANDIDATES := "res://../work/creatures/deathwatch_gestures/candidates.json"

class Arena extends Node3D:
	var avatars: Dictionary = {}

class Avatar extends Node3D:
	var horse_visual: Node3D

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATES))
		assert(rows.size() == 2 and rows[0].presentation == rows[1].presentation)
		Registry.entries[242] = rows[0].presentation
	for tilt: Vector3 in [Vector3.ZERO, Vector3(0.075, 0.0, 0.065), Vector3(-0.068, 0.0, -0.072)]:
		await witness(242, tilt, 0.0)
		await witness(242, tilt, 0.07)
		await witness(242, tilt, 0.43)
	print("DEATHWATCH TERRAIN: 738 reaction poses and nine corpse handoffs over 369 sampled falls")
	quit()

func witness(body: int, tilt: Vector3, phase: float) -> void:
	var continuing := phase > 0.0
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
	box.size = Vector3(8.0, 0.10, 8.0)
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
	if not continuing:
		sample_reactions(game, killed, avatar.horse_visual, ground)
	var displayed_phase := 0.0
	var displayed_speed := 1.0
	var displayed_pose: Array[Transform3D] = []
	if continuing:
		var action := PackedByteArray([0x6e])
		action.append_array(Wire.uint_be(killed, 4))
		action.append_array(PackedByteArray([0, 3, 0, 5, 0, 1, 1, 0, 0]))
		game._handle(action)
		var living: Node3D = avatar.horse_visual
		assert(living.receive_action(game.last_mobile_actions[killed]) and living.current_clip == "Death2")
		var animator: AnimationPlayer = living.animator
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		animator.advance(0.025 if phase < 0.1 else 0.13)
		displayed_phase = animator.current_animation_length * phase
		animator.seek(displayed_phase, true)
		displayed_speed = animator.get_playing_speed()
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
	var clip := "Death2" if continuing else "Death"
	assert(visual.current_clip == clip)
	if continuing:
		assert(is_equal_approx(player.current_animation_position, displayed_phase))
		assert(is_equal_approx(player.get_playing_speed(), displayed_speed))
		assert(is_equal_approx(visual.action_remaining,
			(player.current_animation_length - displayed_phase) / displayed_speed))
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

func sample_reactions(game: Node, serial: int, actor: Node3D, ground: Node3D) -> void:
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var rig: Skeleton3D = actor.skeleton
	var anchor := actor.global_transform
	var categories := {10: "Hit", 11: "Fidget", 15: "LeftRecoil", 16: "RightRecoil", 17: "RearingFidget", 18: "Fidget"}
	var paths := {}
	var head := rig.find_bone("bip01 head")
	for slot: int in categories:
		var action := PackedByteArray([0x6e])
		action.append_array(Wire.uint_be(serial, 4))
		action.append_array(PackedByteArray([0, slot, 0, 5, 0, 1, 1, 0, 0]))
		game._handle(action)
		assert(actor.receive_action(game.last_mobile_actions[serial]) and actor.current_clip == categories[slot])
		player.play(actor.current_clip, 0.0)
		player.advance(0.0)
		var trajectory := PackedVector3Array()
		for frame in 41:
			player.seek(player.current_animation_length * frame / 40.0, true)
			var plane: Dictionary = actor.collapse_plane
			assert(plane.collider == ground)
			var gap := Ground.minimum_plane_gap(actor.collapse_skin, rig, rig.global_transform, plane.position, plane.normal)
			assert(gap > -0.001 and actor.global_transform == anchor,
				"Group %d crossed its support plane by %.5f" % [slot, gap])
			trajectory.append(rig.to_global(rig.get_bone_global_pose(head).origin))
		paths[slot] = trajectory
	assert(paths[11] == paths[18])
	for pair: Array in [[10, 15], [10, 16], [15, 16], [11, 17]]:
		var distance := 0.0
		for frame in 41:
			distance = maxf(distance, paths[pair[0]][frame].distance_to(paths[pair[1]][frame]))
		assert(distance > 0.025)
