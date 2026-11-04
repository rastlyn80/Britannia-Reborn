extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Deaths := preload("res://Presentation/CreatureDeaths.gd")
const Items := preload("res://Presentation/WorldItems.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Actions := preload("res://../scripts/test-pig-reaper-harpy-actions.gd")


class Arena extends Node3D:
	var avatars: Dictionary = {}

class Avatar extends Node3D:
	var horse_visual: Node3D

func _initialize() -> void:
	create_timer(24.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	Registry.load_index()
	for body: int in Actions.ACTIONS:
		Registry.entries[body] = Actions.trial_row(body)
	for tilt: Vector3 in [Vector3.ZERO, Vector3(0.14, 0.0, 0.11), Vector3(-0.12, 0.0, -0.10)]:
		for airborne: bool in [false, true]:
			await witness(30, tilt, airborne)
		await witness(30, tilt, true, true)
		await witness(203, tilt, false)
		await witness(47, tilt, false)
	print("PIG, REAPER AND HARPY LANDING: fifteen decoded 0xAF/removal cases and six explicit airborne collapses, 861 poses")
	quit()

func witness(body: int, tilt: Vector3, airborne: bool, continuing := false) -> void:
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
	var expected_position := 0.0
	if airborne:
		var takeoff := PackedByteArray([0x6e])
		takeoff.append_array(Wire.uint_be(killed, 4))
		takeoff.append_array(PackedByteArray([0, 19, 0, 4, 0, 1, 1, 0, 0]))
		game._handle(takeoff)
		assert(avatar.horse_visual.receive_action(game.last_mobile_actions[killed]) and avatar.horse_visual.current_clip == "Fly")
		var action := PackedByteArray([0x6e])
		action.append_array(Wire.uint_be(killed, 4))
		action.append_array(PackedByteArray([0, 21, 0, 7, 0, 1, 1, 0, 0]))
		game._handle(action)
		assert(avatar.horse_visual.receive_action(game.last_mobile_actions[killed]) and avatar.horse_visual.dead)
		assert(avatar.horse_visual.current_clip == "AirDeath")
		sample_collapse(avatar.horse_visual, ground, "AirDeath")
		if continuing:
			var player: AnimationPlayer = avatar.horse_visual.animator
			expected_position = player.current_animation_length * 0.5
			player.seek(expected_position, true)
		else:
			avatar.horse_visual.dead = false
			game._handle(takeoff)
			assert(avatar.horse_visual.receive_action(game.last_mobile_actions[killed]))
			avatar.horse_visual.contact.contacts.clear()
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
	var clip := "AirDeath" if airborne else "Death"
	assert(visual.current_clip == clip and visual.animator.assigned_animation == clip)
	assert(absf(visual.animator.current_animation_position - expected_position) < 0.001)
	var plane: Dictionary = visual.collapse_plane
	sample_collapse(visual, ground, clip)
	var removal := PackedByteArray([0x1d])
	removal.append_array(Wire.uint_be(killed, 4))
	game._handle(removal)
	arena.avatars.erase(killed)
	avatar.free()
	deaths._process(float(deaths.active[killed].remaining) + 0.1)
	assert(holder.visible and deaths.active.is_empty() and items.corpse_snapshots.has(serial))
	var cadaver := holder.get_node("CorpseVisual") as Node3D
	assert(cadaver.get_meta("corpse_body") == body and cadaver.get_meta("native_hue") == 0x8035)
	assert(cadaver.get_meta("static_cadaver") and cadaver.find_children("*", "Skeleton3D", true, false).is_empty())
	var least := INF
	for mesh: MeshInstance3D in cadaver.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var points: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point: Vector3 in points:
				least = minf(least, (mesh.to_global(point) - plane.position).dot(plane.normal))
	var expected := 0.003 if body == 30 else 0.002
	print(clip, " ", tilt, " frozen gap ", least)
	assert(absf(least - expected) < 0.0015, "Corpse maintains the displayed terrain clearance")
	assert(cadaver.get_meta("death_clip") == clip)
	arena.free()
	game.free()


func sample_collapse(visual: Node3D, ground: StaticBody3D, clip: String) -> void:
	var rig: Skeleton3D = visual.skeleton
	var player: AnimationPlayer = visual.animator
	var anchor := visual.global_transform
	var plane: Dictionary = visual.collapse_plane
	assert(plane.collider == ground)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play(clip, 0.0)
	player.advance(0.0)
	for frame in 41:
		player.seek(player.current_animation_length * frame / 40.0, true)
		var gap := Ground.minimum_plane_gap(visual.collapse_skin, rig, rig.global_transform, plane.position, plane.normal)
		assert(is_finite(gap) and gap > -0.001 and visual.global_transform == anchor)
		if frame == 0 and clip == "AirDeath":
			print(clip, " ", ground.rotation, " initial gap ", gap)
			var expected_start := 0.571 if ground.rotation.is_zero_approx() else (0.341 if ground.rotation.x > 0.0 else 0.410)
			assert(absf(gap - expected_start) < 0.018, "Airborne wing clearance follows the local plane")
		if frame == 40:
			assert(absf(gap - (0.003 if visual.native_body == 30 else 0.002)) < 0.001)
