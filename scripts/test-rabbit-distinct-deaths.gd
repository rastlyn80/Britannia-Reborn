extends SceneTree

const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const BODY := 205
const COLLAPSES := {8: "Death", 12: "Death2"}
const PLANES := [Vector3.ZERO, Vector3(0.14, 0.0, 0.10), Vector3(-0.12, 0.0, -0.08)]
const Deaths := preload("res://Presentation/CreatureDeaths.gd")
const Rabbit := preload("res://Presentation/RabbitActionsVisual.gd")
const Items := preload("res://Presentation/WorldItems.gd")

class Arena extends Node3D:
	var avatars: Dictionary = {}

class Avatar extends Node3D:
	var horse_visual: Node3D

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	if "--candidate" in OS.get_cmdline_user_args():
		var row := Registry.entry(BODY).duplicate(true)
		row.assets = {"modern": "res://local-art/creatures/rabbit-actions-candidate.scn"}
		row.presentation_script = "res://Presentation/RabbitActionsVisual.gd"
		row.classic_action_categories = {"6": "RabbitLunge", "10": "RabbitEarCheck", "12": "Death2"}
		Registry.entries[BODY] = row
	for tilt: Vector3 in PLANES:
		for group: int in COLLAPSES:
			await witness(group, tilt)
	print("RABBIT DEATH PACKETS: six decoded death, removal and corpse handoffs with 246 body and fur poses")
	quit()

func witness(group: int, tilt: Vector3) -> void:
	var arena := Arena.new()
	root.add_child(arena)
	var game := Game.new()
	arena.add_child(game)
	game.set_process(false)
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
	box.size = Vector3(8.0, 0.1, 8.0)
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position.y = -0.05
	ground.add_child(shape)
	await physics_frame
	await physics_frame
	var killed := 10000 + BODY
	var corpse := 0x40010000 + BODY
	var avatar := Avatar.new()
	arena.add_child(avatar)
	var source := Registry.create(BODY)
	assert(source is Rabbit)
	avatar.horse_visual = source
	avatar.add_child(source)
	assert(source.contact.feet.size() == 4)
	source.apply_identity(BODY, 0x8035)
	source.set_physics_process(false)
	arena.avatars[killed] = avatar
	game.entities[killed] = {"serial": killed, "body": BODY, "hue": 0x8035, "direction": 4}
	if group == 12:
		var action := PackedByteArray([0x6e])
		action.append_array(Wire.uint_be(killed, 4))
		action.append_array(PackedByteArray([0, 12, 0, 5, 0, 1, 1, 0, 0]))
		game._handle(action)
		assert(source.receive_action(game.last_mobile_actions[killed]))
		source.animator.advance(0.0)
		source.animator.seek(source.animator.current_animation_length * 0.4, true)
	var holder := Node3D.new()
	items.add_child(holder)
	items.nodes[corpse] = holder
	assert(items._equine_corpse(holder, {"id": 0x2006, "amount": BODY, "hue": 0x8035, "direction": 4}, corpse))
	var packet := PackedByteArray([0xaf])
	packet.append_array(Wire.uint_be(killed, 4))
	packet.append_array(Wire.uint_be(corpse, 4))
	packet.append_array(Wire.uint_be(0, 4))
	game._handle(packet)
	assert(deaths.active.has(killed) and not holder.visible and not avatar.visible)
	var visual: Node3D = deaths.active[killed].visual
	var player: AnimationPlayer = visual.animator
	assert(visual.current_clip == COLLAPSES[group])
	var start := player.current_animation_position
	assert(absf(start / player.current_animation_length - (0.4 if group == 12 else 0.0)) < 0.001)
	var plane: Dictionary = visual.collapse_plane
	assert(plane.collider == ground)
	var anchor := visual.global_transform
	for frame in 41:
		player.seek(lerpf(start, player.current_animation_length, frame / 40.0), true)
		var gap: float = visual.skin_gap(visual.skeleton.global_transform, plane.position, plane.normal)
		assert(is_finite(gap) and gap > -0.001 and visual.global_transform == anchor)
		if frame == 40:
			assert(absf(gap - 0.0025) < 0.001)
	var removal := PackedByteArray([0x1d])
	removal.append_array(Wire.uint_be(killed, 4))
	game._handle(removal)
	arena.avatars.erase(killed)
	avatar.free()
	deaths._process(float(deaths.active[killed].remaining) + 0.1)
	assert(holder.visible and deaths.active.is_empty() and items.corpse_snapshots.has(corpse))
	var frozen := holder.get_node("CorpseVisual") as Node3D
	assert(frozen.get_meta("corpse_body") == BODY and frozen.get_meta("native_hue") == 0x8035)
	assert(frozen.get_meta("death_clip") == COLLAPSES[group] and frozen.get_meta("static_cadaver"))
	assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
	assert(frozen.find_children("*", "MeshInstance3D", true, false).size() == 2)
	var minimum := INF
	for mesh: MeshInstance3D in frozen.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var points: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point: Vector3 in points:
				minimum = minf(minimum, plane.normal.dot(mesh.to_global(point) - plane.position))
	assert(absf(minimum - 0.0025) < 0.001)
	arena.free()
