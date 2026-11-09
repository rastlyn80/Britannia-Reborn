extends SceneTree
const SealedBase := preload("res://Presentation/SealedCreatureActionBase.gd")
const Registry = preload("res://Presentation/CreatureRegistry.gd")
const Avatar = preload("res://Presentation/HumanAvatar.gd")
const Lord = preload("res://Presentation/SourceJukaLordVisual.gd")
const Game = preload("res://Network/GameSession.gd")
const Wire = preload("res://Network/LoginProtocol.gd")
func _initialize() -> void:
	create_timer(15.0).timeout.connect(func(): quit(2))
	call_deferred("run")
func run() -> void:
	Registry.load_index()
	var preparation: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://local-art/creatures/juka_lord/preparation.json"))
	var expected: Dictionary = preparation.models[0].duplicate(true)
	expected.status = "validated"
	var active := Registry.entry(766)
	var base := SealedBase.retained(active, 766) if active.get("classic_gesture_batch") == "golem_raptor_juka_solen_actions" else active
	assert(Registry.supports_body(766) and base == expected)
	var avatar := Avatar.new()
	avatar.initial_body = 766
	root.add_child(avatar)
	avatar.set_physics_process(false)
	var visual := avatar.horse_visual as Lord
	assert(visual != null)
	visual.set_physics_process(false)
	visual.set_process(false)
	var serial := 0x1234
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[serial] = {"serial": serial, "body": 766, "hue": 0}
	game.appearance_changed.connect(func(owner: int):
		if owner == serial:
			avatar.apply_server_appearance(game.entities[serial], game.mobile_equipment.get(serial, {}).values()))
	game.mobile_action_received.connect(func(action: Dictionary):
		assert(avatar.receive_native_action(action)))
	assert(visual.bow_holder == null)
	for graphic: int in [0x13b2, 0x13b1]:
		var item := 0x40001234 + graphic
		var packet := PackedByteArray([0x2e])
		packet.append_array(Wire.uint_be(item, 4))
		packet.append_array(Wire.uint_be(graphic, 2))
		packet.append_array(PackedByteArray([0, 2]))
		packet.append_array(Wire.uint_be(serial, 4))
		packet.append_array(Wire.uint_be(0, 2))
		game._handle(packet)
		assert(visual.bow_holder != null and visual.bow_holder.visible)
		var action := PackedByteArray([0x6e])
		action.append_array(Wire.uint_be(serial, 4))
		action.append_array(PackedByteArray([0, 7, 0, 5, 0, 1, 1, 0, 0]))
		game._handle(action)
		assert(game.last_mobile_actions[serial].action == 7 and visual.current_clip == "AttackBow")
		var animator: AnimationPlayer = visual.animator
		for phase in [.1, .4, .85]:
			animator.seek(animator.current_animation_length * phase, true)
			visual.update_bow()
			assert((visual.bow_mesh.mesh != visual.rest_mesh) == (phase == .4))
		var remove := PackedByteArray([0x1d])
		remove.append_array(Wire.uint_be(item, 4))
		game._handle(remove)
		assert(not visual.bow_holder.visible)
	await process_frame
	await RenderingServer.frame_post_draw
	avatar.queue_free()
	game.queue_free()
	await process_frame
	print("JUKA LORD PACKETS: decoded equip, attack, draw, release and removal for both graphics")
	quit()
