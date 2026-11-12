extends SceneTree

const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Animals := preload("res://Presentation/AnimalVisual.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const COLLAPSES := {8: "Death", 12: "Death2"}
const PLANES := [Vector3.ZERO, Vector3(0.14, 0.0, 0.10), Vector3(-0.12, 0.0, -0.08)]
const Deaths := preload("res://Presentation/CreatureDeathsWithBovines.gd")
const Bovine := preload("res://Presentation/BovineActionsVisual.gd")
const Terrain := preload("res://Presentation/BovineLivingGround.gd")
const Items := preload("res://Presentation/WorldItems.gd")

class Arena extends Node3D:
	var avatars: Dictionary = {}

class Avatar extends Node3D:
	var horse_visual: Node3D

func _initialize() -> void:
	create_timer(35.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	Animals.bovine_actions_trial = "--candidate" in OS.get_cmdline_user_args()
	var transfers := 0
	for body: int in Animals.BODIES:
		for treatment: String in ["original", "rounded", "modern"]:
			for tilt: Vector3 in PLANES:
				for group: int in COLLAPSES:
					if not await witness(body, group, treatment, tilt):
						quit(1)
						return
					transfers += 1
	print("BOVINE DEATH PACKETS: ", transfers, " decoded death, removal and corpse handoffs with ", transfers * 41, " poses")
	quit()

func witness(body: int, group: int, treatment: String, tilt: Vector3) -> bool:
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
	var killed := 10000 + body
	var corpse := 0x40010000 + body
	var avatar := Avatar.new()
	arena.add_child(avatar)
	var source := Animals.create(body)
	assert(source is Bovine)
	source.treatment = treatment
	avatar.horse_visual = source
	avatar.add_child(source)
	source.apply_identity(body, 0x8035)
	source.set_physics_process(false)
	arena.avatars[killed] = avatar
	game.entities[killed] = {"serial": killed, "body": body, "hue": 0x8035, "direction": 4}
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
	assert(items._equine_corpse(holder, {"id": 0x2006, "amount": body, "hue": 0x8035, "direction": 4}, corpse))
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
	var terrain := visual.get("ground") as Terrain
	var transferred := terrain != null and terrain.transferring
	var plane: Dictionary = terrain.fall.plane if transferred else visual.collapse_plane
	var skin: Dictionary = terrain.fall.skin if transferred else visual.collapse_skin
	assert(plane.get("collider") == ground)
	var anchor := visual.global_transform
	var rig: Skeleton3D = visual.skeleton
	for frame in 41:
		player.seek(lerpf(start, player.current_animation_length, frame / 40.0), true)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.position, plane.normal)
		assert(is_finite(gap) and gap > -0.001 and visual.global_transform == anchor)
		if frame == 40:
			assert(absf(gap - 0.002) < 0.001)
	var removal := PackedByteArray([0x1d])
	removal.append_array(Wire.uint_be(killed, 4))
	game._handle(removal)
	arena.avatars.erase(killed)
	avatar.free()
	deaths._process(float(deaths.active[killed].remaining) + 0.1)
	assert(holder.visible and deaths.active.is_empty() and items.corpse_snapshots.has(corpse))
	var frozen := holder.get_node("CorpseVisual") as Node3D
	assert(frozen.get_meta("corpse_body") == body and frozen.get_meta("native_hue") == 0x8035)
	assert(frozen.get_meta("death_clip") == COLLAPSES[group] and frozen.get_meta("static_cadaver"))
	assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
	var minimum := INF
	for mesh: MeshInstance3D in frozen.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var points: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point: Vector3 in points:
				minimum = minf(minimum, plane.normal.dot(mesh.to_global(point) - plane.position))
	assert(absf(minimum - 0.002) < 0.001)
	arena.free()
	return true
