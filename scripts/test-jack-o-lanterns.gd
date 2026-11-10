# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Game := preload("res://Network/GameSession.gd")
const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Corpse := preload("res://Presentation/CorpseModels.gd")
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const BODIES := [1246, 1247]
const HUES := [0, 53, 0x8035]
const SLOPES := [Vector3.ZERO, Vector3(.13, 0., 0.), Vector3(0., 0., -.16)]
var route_count := 0
var poses := 0
var static_count := 0
var least := INF

func _initialize() -> void:
	create_timer(45.).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	for body: int in BODIES:
		var row := Registry.entry(body)
		assert(row.has("jack_o_lantern_source") and Registry.supports_body(body))
		assert(row.classic_action_categories.size() == 29 and row.new_action_categories.size() == 8)
		var avatar := Avatar.new()
		avatar.initial_body = body
		root.add_child(avatar)
		avatar.apply_server_appearance({"serial": body, "body": body, "hue": 53, "flags": 0}, [])
		assert(avatar.horse_visual != null and avatar.horse_visual.native_hue == 53 and avatar.human_visual == null)
		var actor: Node3D = avatar.horse_visual
		var player: AnimationPlayer = actor.animator
		var flame: ShaderMaterial = actor.flame_materials[0]
		assert(flame.get_shader_parameter("use_hue") == true)
		actor.set_hue(0x8035)
		assert(actor.flame_materials[0].get_shader_parameter("use_hue") == false)
		actor.set_hue(0)
		assert(actor.flame_materials[0].get_shader_parameter("hue_palette") == null)
		actor.play_gait(true, 2.0)
		assert(actor.current_clip == "Walk")
		actor.play_gait(true, 5.0)
		assert(actor.current_clip == "Run")
		game.entities[body] = {"serial": body, "body": body, "hue": 53}
		for protocol: String in ["classic", "new"]:
			var expected: Dictionary = row.classic_action_categories if protocol == "classic" else row.new_action_categories
			for key: String in expected:
				actor.dead = false
				player.stop()
				assert(actor.receive_action(decode(game, body, int(key), protocol)), str([body, protocol, key]))
				assert(actor.current_clip == expected[key], str([body, protocol, key, actor.current_clip, expected[key]]))
				route_count += 1
		avatar.free()
		for hue: int in HUES:
			var frozen := Corpse.build(body, hue)
			assert(frozen != null and frozen.get_meta("static_cadaver") and frozen.get_meta("corpse_body") == body)
			assert(frozen.get_meta("graphic_id") == 0x2006 and frozen.get_meta("native_hue") == hue)
			assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
			var box: AABB = frozen.get_meta("corpse_bounds")
			assert(is_zero_approx(box.position.y) and box.size.y > .20 and box.size.y < .70 and box.size.x > .45, str(box))
			for mesh: MeshInstance3D in frozen.find_children("*", "MeshInstance3D", true, false):
				assert(not str(mesh.name).begins_with("Flame") and not str(mesh.name).begins_with("Jaw"))
			frozen.free()
			static_count += 1
	for tilt: Vector3 in SLOPES:
		var ground := await terrain(tilt)
		for body: int in BODIES:
			var actor := Registry.create(body)
			root.add_child(actor)
			actor.apply_identity(body, 0)
			actor.set_physics_process(false)
			actor.set_process(false)
			var pose_anchor := actor.global_transform
			var player: AnimationPlayer = actor.animator
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			for action: String in ["Idle", "Walk", "Run", "Attack", "Hit", "Fidget", "Death", "Dormant", "Ignite"]:
				player.stop()
				actor.dead = false
				actor._physics_process(1.0 / 60.)
				player.play(action, 0.0)
				player.advance(0.0)
				var length := player.current_animation_length
				for step in 25:
					player.seek(length * step / 24.0, true)
					actor.place_visual()
					var gap: float = actor.lowest_gourd(actor.gourd.global_transform, ground.global_position, ground.global_basis.y.normalized())
					assert(absf(gap - .002) < .002 and actor.global_transform == pose_anchor,
						str([body, action, step, tilt, gap]))
					least = minf(least, gap)
					poses += 1
					if step == 0 and action == "Ignite":
						assert(not actor.spirit.visible)
				if action == "Death" or action == "Dormant":
					assert(not actor.spirit.visible, str([body, action, tilt, player.current_animation_position]))
				elif action == "Ignite":
					assert(actor.spirit.visible)
			player.stop()
			actor.dead = false
			assert(actor.receive_action(decode(game, body, 2, "classic")))
			player.advance(0.0)
			player.seek(player.current_animation_length * .55, true)
			var transition := Registry.create(body)
			root.add_child(transition)
			transition.apply_identity(body, 0)
			transition.dead = true
			transition.model.transform = actor.model.transform
			var remainder: float = transition.begin_death_from(actor)
			assert(remainder > 0. and remainder < 1.5 and transition.spirit.visible)
			transition.animator.seek(transition.animator.current_animation_length, true)
			transition.place_visual()
			var frozen := Snapshot.capture(transition, transition.corpse_snapshot_floor())
			assert(not frozen.is_empty() and int(frozen.body) == body)
			transition.free()
			actor.free()
		ground.free()
		await physics_frame
	game.free()
	assert(route_count == 74 and poses == 1350 and static_count == 6)
	var trial := OS.get_environment("BR_FORM_TEST_DIR")
	if not trial.is_empty():
		var report := FileAccess.open(trial.path_join("jack-o-lanterns/presentation.json"), FileAccess.WRITE)
		report.store_string(JSON.stringify({"decoded_routes": route_count, "terrain_poses": poses,
			"corpse_hues": static_count, "minimum_plane_gap": least, "index_sha256": FileAccess.get_sha256(
			"res://local-art/creatures/accepted-index.json"), "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		report.close()
	print("JACK O' LANTERN CLIENT: ", route_count, " decoded actions, ", poses, " terrain poses, ",
		static_count, " static corpse hues; minimum gap ", least)
	quit()

func decode(game: Node, serial: int, key: int, protocol: String) -> Dictionary:
	var packet := PackedByteArray([0x6e if protocol == "classic" else 0xe2, 0, 0, (serial >> 8) & 255, serial & 255])
	if protocol == "classic":
		packet.append_array(PackedByteArray([0, key, 0, 6, 0, 1, 1, 0, 0]))
	else:
		packet.append_array(PackedByteArray([0, key, 0, 0, 0]))
	game._handle(packet)
	return game.last_mobile_actions[serial]

func terrain(tilt: Vector3) -> StaticBody3D:
	var ground := StaticBody3D.new()
	root.add_child(ground)
	ground.rotation = tilt
	var box := BoxShape3D.new()
	box.size = Vector3(7., .10, 7.)
	var collider := CollisionShape3D.new()
	collider.shape = box
	collider.position.y = -.05
	ground.add_child(collider)
	await physics_frame
	await physics_frame
	return ground
