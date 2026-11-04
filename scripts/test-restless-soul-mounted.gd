extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Deaths := preload("res://Presentation/CreatureDeaths.gd")
const Renderer := preload("res://Presentation/RestlessSoulMountedVisual.gd")
const PACKAGE := "res://local-art/creatures/restless_soul_mounted/preparation.json"
const SERIAL := 0x4200
const BODY := 970
const GHOST_HUE := 0x453

class Arena extends Node3D:
	var avatars: Dictionary = {}

class Items extends Node:
	var nodes: Dictionary = {}

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	Registry.load_index()
	if "--active" not in OS.get_cmdline_user_args():
		Registry.entries[BODY] = JSON.parse_string(FileAccess.get_file_as_string(PACKAGE)).models[1]
	var row := Registry.entry(BODY)
	assert(row.family == "restless_soul_mounted")
	var frames: Dictionary = row.get("mounted_action_witness_frames", row.action_witness_frames)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var entity := {"serial": SERIAL, "body": BODY, "hue": GHOST_HUE, "direction": 4}
	game.entities[SERIAL] = entity
	var checked := 0
	var maximum_seat := 0.0
	var minimum_ankle := INF
	for treatment: String in ["original", "rounded", "modern"]:
		var avatar := Avatar.new()
		avatar.initial_body = BODY
		root.add_child(avatar)
		avatar.set_physics_process(false)
		if treatment != "modern":
			avatar.horse_visual.free()
			var custom := Registry.create(BODY)
			custom.treatment = treatment
			avatar.visual_root.add_child(custom)
			avatar.horse_visual = custom
		var visual := avatar.horse_visual as Renderer
		assert(visual != null)
		visual.set_process(false)
		visual.set_physics_process(false)
		var anchor := visual.global_transform
		for graphic: int in [0x3e9f, 0x3ea0, 0x3ea3]:
			assert(not request_action(game, avatar, frames, 25))
			var layer := {"id": graphic, "layer": 25, "hue": 0x489, "serial": 0x40001234}
			avatar.apply_server_appearance(entity, [layer])
			assert(visual.mount != null and not visual.model.visible)
			assert(visual.mount.native_hue == 0x489 and visual.mount.native_mount_item == graphic)
			assert(visual.native_hue == GHOST_HUE and visual.current_clip == Renderer.Seats[25])
			visual.mount.set_process(false)
			visual.mount.set_physics_process(false)
			var instance := visual.mount.get_instance_id()
			var rider_instance := visual.seated_model.get_instance_id()
			layer.hue = 0x47e
			avatar.apply_server_appearance(entity, [layer])
			assert(visual.mount.get_instance_id() == instance and visual.mount.native_hue == 0x47e)
			assert(visual.seated_model.get_instance_id() == rider_instance)
			for slot: int in Renderer.Seats:
				assert(request_action(game, avatar, frames, slot) and visual.current_clip == Renderer.Seats[slot])
				var expected := float(frames[str(slot)]) * 0.16
				assert(is_equal_approx(visual.action_remaining, expected))
				var rider := visual.seated_player
				var steed: AnimationPlayer = visual.mount.animator
				visual.mount.play_gait(slot in [23, 24], 4.7 if slot == 24 else 1.8)
				steed.advance(0.0)
				for frame in 25:
					var phase := float(frame) / 24.0
					steed.seek(steed.current_animation_length * phase, true)
					rider.seek(rider.current_animation_length * phase, true)
					steed.pause()
					rider.pause()
					visual.mount.skeleton.force_update_all_bone_transforms()
					visual.seated_rig.force_update_all_bone_transforms()
					visual.fit_to_saddle()
					var saddle: Transform3D = visual.mount.seat()
					var left := saddle.affine_inverse() * visual.joint_world(visual.seated_rig.find_bone("bip01 l foot"))
					var right := saddle.affine_inverse() * visual.joint_world(visual.seated_rig.find_bone("bip01 r foot"))
					var seat := visual.joint_world(visual.pelvis).distance_to(saddle * Vector3(0, 0.105, 0))
					assert(seat < 0.0001 and left.x * right.x < 0 and left.y < 0 and right.y < 0)
					assert(visual.global_transform == anchor and visual.get_meta("pick_bounds").has_volume())
					maximum_seat = maxf(maximum_seat, seat)
					minimum_ankle = minf(minimum_ankle, minf(absf(left.x), absf(right.x)))
					checked += 1
			visual._process(1.6)
			visual.play_gait(true, 4.9)
			assert(visual.current_clip == Renderer.Seats[24])
			avatar.apply_server_appearance(entity, [])
			assert(visual.mount == null and visual.model.visible and visual.current_clip == "Idle")
			assert(not is_instance_id_valid(instance) and not is_instance_id_valid(rider_instance))
			assert(not request_action(game, avatar, frames, 23))
		avatar.free()
	check_death(game, entity)
	game.free()
	print("RESTLESS SOUL MOUNTED PASS: ", checked, " posed seats; max error ", maximum_seat,
		"; nearest lateral ankle ", minimum_ankle, "; dyed remount and decoded death")
	quit()

func request_action(game: Node, avatar: Node3D, frames: Dictionary, slot: int) -> bool:
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(SERIAL, 4))
	packet.append_array(PackedByteArray([0, slot, 0, int(frames[str(slot)]), 0, 1, 1, 0, 0]))
	game._handle(packet)
	return avatar.receive_native_action(game.last_mobile_actions[SERIAL])

func check_death(game: Node, entity: Dictionary) -> void:
	var arena := Arena.new()
	root.add_child(arena)
	var items := Items.new()
	var deaths := Deaths.new()
	arena.add_child(items)
	arena.add_child(deaths)
	deaths.configure(arena, game, items)
	var avatar := Avatar.new()
	avatar.initial_body = BODY
	arena.add_child(avatar)
	arena.avatars[SERIAL] = avatar
	avatar.apply_server_appearance(entity, [{"id": 0x3e9f, "layer": 25, "hue": 0, "serial": 0x40001234}])
	assert(avatar.horse_visual.mount != null)
	var packet := PackedByteArray([0xaf])
	packet.append_array(Wire.uint_be(SERIAL, 4))
	packet.append_array(Wire.uint_be(0x40004321, 4))
	packet.append_array(PackedByteArray([0, 0, 0, 0]))
	game._handle(packet)
	assert(deaths.active.has(SERIAL))
	var collapsed: Node3D = deaths.active[SERIAL].visual
	assert(collapsed.mount == null and collapsed.model.visible and collapsed.current_clip == "Death")
	assert(not avatar.visible and deaths.held_corpses.has(0x40004321))
	arena.free()
