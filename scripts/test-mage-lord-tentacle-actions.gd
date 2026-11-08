extends SceneTree

const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const Earlier := preload("res://../scripts/test-quadruped-actions.gd")
const FAMILY := "mage_lord_tentacle_actions"
const SLOPES := [Vector3.ZERO, Vector3(0.08, 0.0, -0.06), Vector3(-0.07, 0.0, 0.08)]
const TREATMENTS := ["original", "rounded", "modern"]
const BODIES := [125, 126, 66]
const WORN := [{"id":7939, "layer":22, "hue":0x35}, {"id":5912, "layer":6, "hue":0x8035},
	{"id":5901, "layer":3, "hue":0x45}]

var checked := 0

func _initialize() -> void:
	create_timer(160.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	load_routes()
	var session := Game.new()
	root.add_child(session)
	session.set_process(false)
	for body: int in BODIES:
		var row := Registry.entry(body)
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue, WORN if is_lord(body) else [])
			assert(corpse.get_meta("corpse_body") == body and corpse.get_meta("native_hue") == hue
				and corpse.get_meta("death_clip") == "Death" and corpse.get_meta("static_cadaver"))
			if is_lord(body):
				assert(costume_material(corpse, hue))
			corpse.free()
		for tilt: Vector3 in SLOPES:
			var plane := await support(tilt)
			for treatment: String in TREATMENTS:
				sample_routes(session, body, row, treatment, plane)
			plane.free()
			await physics_frame
	check_shared_tentacle()
	print("EVIL MAGE LORD AND SWAMP TENTACLE: ", checked, " decoded terrain poses and nine static corpse hues")
	quit()

func load_routes() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var path := "res://../work/creatures/%s/prepared-client.json" % FAMILY
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert(rows.size() == 3)
		for row: Dictionary in rows:
			var body := int(row.bodies[0].body)
			assert(body in BODIES and row.status == "prepared" and row.family == FAMILY)
			row.kind += "_actions_%d" % body
			Registry.entries[body] = row
	else:
		for body: int in BODIES:
			assert(Registry.entry(body).get("classic_gesture_batch") == FAMILY)
	assert(Registry.entry(129).kind == "flails_swamp_tentacles")
	assert(Registry.entry(124).kind == "mages_evil_mage")

func sample_routes(session: Node, body: int, row: Dictionary, treatment: String, plane: StaticBody3D) -> void:
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	assert(rig.get_bone_count() == (36 if is_lord(body) else 46))
	assert(actor.native_body == body and actor.native_hue == 0x8035)
	if plane.rotation == Vector3.ZERO:
		Earlier.check_earlier_keys(player, row.classic_gesture_base_assets[treatment])
	if is_lord(body):
		actor.set_equipment(WORN)
		if treatment == "modern":
			assert(costume_material(actor.model, 0x8035))
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var groups: Array = row.classic_motion_references.keys()
	if body == 66:
		groups = ["6", "18", "3"]
	var normal := plane.global_basis.y.normalized()
	for group: String in groups:
		assert(actor.receive_action(decode(session, body, int(group))))
		assert(actor.current_clip == row.classic_action_categories[group])
		player.advance(0.18)
		var lowest := INF
		for step in 17:
			player.seek(player.current_animation_length * step / 16.0, true)
			if is_lord(body):
				actor.contact.sample(plane.get_world_3d().direct_space_state, actor.global_position)
				assert(actor.contact.contacts.size() == 2)
				actor.contact._process_modification_with_delta(0.0)
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
			lowest = minf(lowest, gap)
			assert(actor.global_transform == Transform3D.IDENTITY and is_finite(gap)
				and gap >= (-0.012 if is_lord(body) else 0.0015),
				"Ground gap %s at %s/%s/%s/%d" % [gap, body, treatment, group, step])
			checked += 1
		print(body, " ", treatment, " group ", group, " slope ", plane.rotation, " minimum gap ", lowest)
	actor.free()

func check_shared_tentacle() -> void:
	var avatar := Avatar.new()
	avatar.initial_body = 66
	root.add_child(avatar)
	avatar.apply_server_appearance({"body":66, "hue":0x8035}, [])
	assert(avatar.horse_visual.animator.has_animation("DoubleWhip"))
	avatar.apply_server_appearance({"body":129, "hue":0x8035}, [])
	assert(avatar.horse_visual.native_body == 129 and not avatar.horse_visual.animator.has_animation("DoubleWhip"))
	avatar.apply_server_appearance({"body":66, "hue":53}, [])
	assert(avatar.horse_visual.native_body == 66 and avatar.horse_visual.animator.has_animation("DoubleWhip"))
	avatar.free()

static func is_lord(body: int) -> bool:
	return body in [125, 126]

static func costume_material(node: Node3D, hue: int) -> bool:
	var mesh := node.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var material := mesh.get_active_material(0) as ShaderMaterial
	return material != null and bool(material.get_shader_parameter("body_partial")) == ((hue & 0x8000) != 0) \
		and bool(material.get_shader_parameter("use_robe")) and bool(material.get_shader_parameter("use_shoes")) \
		and bool(material.get_shader_parameter("hat_partial")) and bool(material.get_shader_parameter("use_hat"))

static func decode(session: Node, serial: int, group: int) -> Dictionary:
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(PackedByteArray([0, group, 0, 6, 0, 1, 1, 0, 0]))
	session._handle(packet)
	return session.last_mobile_actions[serial]

func support(tilt: Vector3) -> StaticBody3D:
	var ground := StaticBody3D.new()
	root.add_child(ground)
	ground.rotation = tilt
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 0.10, 8.0)
	var collider := CollisionShape3D.new()
	collider.shape = box
	collider.position.y = -0.05
	ground.add_child(collider)
	await physics_frame
	await physics_frame
	return ground
