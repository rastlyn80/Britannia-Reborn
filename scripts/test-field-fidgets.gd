extends "res://../scripts/test-spider-mongbat-gestures.gd"

const TRIAL_FORMS := [
	[237, "deer_doe", {4: "DeerGroundCheck", 9: "DeerPaw", 10: "Fidget2"}],
	[234, "deer_stag", {4: "DeerGroundCheck", 9: "Fidget", 10: "Fidget2"}],
	[238, "rat", {9: "RatRear", 10: "Fidget2"}],
]

func run() -> void:
	Registry.load_index()
	var deck := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10.0, 0.1, 10.0)
	collider.shape = box
	collider.position.y = -0.05
	deck.add_child(collider)
	root.add_child(deck)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var rat_only := "--rat" in OS.get_cmdline_user_args()
	var active := "--active" in OS.get_cmdline_user_args()
	var batch := "rat_fidgets" if rat_only else "deer_fidgets"
	var checked := 0
	for form: Array in TRIAL_FORMS:
		var body: int = form[0]
		if (body == 238) != rat_only:
			continue
		if not active:
			var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/%s/candidates.json" % batch))
			var rows := candidates.filter(func(item: Dictionary) -> bool: return int(item.body) == body)
			assert(not rows.is_empty())
			for row: Dictionary in rows:
				assert(row.presentation == rows[0].presentation)
			Registry.entries[body] = rows[0].presentation
		var row := Registry.entry(body)
		game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0}
		for treatment: String in (["modern"] if rat_only else ["original", "rounded", "modern"]):
			assert(FileAccess.get_sha256(row.assets[treatment]) == row.authored_action_scene_sha256[treatment])
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			var source := "res://Art/Creatures/Rat/rat.glb" if rat_only else "res://local-art/creatures/%s-%s.gltf" % [form[1], treatment]
			check_tracks(actor.animator, source)
			for tilt: Vector3 in [Vector3.ZERO, Vector3(0.08, 0.0, -0.08), Vector3(-0.09, 0.0, 0.11)]:
				deck.rotation = tilt
				await physics_frame
				await physics_frame
				for slot: int in form[2]:
					var packet := PackedByteArray([0x6e])
					packet.append_array(Wire.uint_be(SERIAL, 4))
					packet.append_array(PackedByteArray([0, slot, 0, 5 if slot == 9 else 3, 0, 1, 1, 0, 0]))
					game._handle(packet)
					assert(probe(actor, deck, form[2][slot], game.last_mobile_actions[SERIAL]))
					checked += 1
			actor.free()
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("native_hue") == hue)
			assert(corpse.get_meta("graphic_id") == 0x2006 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			corpse.free()
	game.free()
	deck.free()
	print(batch, ": ", checked, " decoded terrain runs, exact earlier tracks and static corpse hues")
	quit()

func probe(actor: Node3D, deck: StaticBody3D, clip: String, request: Dictionary) -> bool:
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var rat: bool = actor.native_body == 238
	var head := rig.find_bone("head" if rat else "bip01 head")
	var paw := rig.find_bone("base.001_L.001" if rat else "bip01 l hand")
	var root_before := actor.global_transform
	player.stop()
	actor.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 60:
		actor._physics_process(1.0 / 60.0)
	assert(actor.receive_action(request) and actor.current_clip == clip)
	var dt: float = actor.action_remaining / 40.0
	var floor := INF
	var head_range := Vector2(INF, -INF)
	var paw_range := Vector2(INF, -INF)
	for frame in 41:
		player.advance(0.0 if frame == 0 else dt)
		actor._physics_process(dt)
		actor.contact._process_modification_with_delta(dt)
		rig.force_update_all_bone_transforms()
		actor.contact.modification_processed.emit()
		assert(root_before.is_equal_approx(actor.global_transform))
		floor = minf(floor, Ground.minimum_plane_gap(skin, rig, rig.global_transform, deck.position, deck.basis.y))
		var h := rig.to_global(rig.get_bone_global_pose(head).origin).y
		var p := rig.to_global(rig.get_bone_global_pose(paw).origin).y
		head_range = Vector2(minf(h, head_range.x), maxf(h, head_range.y))
		paw_range = Vector2(minf(p, paw_range.x), maxf(p, paw_range.y))
	actor._process(actor.action_remaining + 0.001)
	actor.play_gait(false, 0.0)
	assert(actor.current_clip == "Idle" and actor.native_hue == 0x8035)
	print(actor.native_body, " ", actor.treatment, " ", clip, " on ", deck.rotation, " floor ", floor, " head ", head_range, " front ankle ", paw_range)
	var head_travel := head_range.y - head_range.x
	var paw_travel := paw_range.y - paw_range.x
	if rat:
		return floor >= -0.005 and (head_travel > 0.115 and paw_travel > 0.06 if clip == "RatRear" else head_travel < 0.02)
	if clip == "DeerGroundCheck":
		return floor >= -0.017 and head_range.x < 0.55 and paw_travel < 0.07
	if clip == "Fidget2":
		return floor >= -0.017 and head_travel > 0.10 and paw_travel < 0.08
	return floor >= -0.017 and paw_travel > 0.045 and (actor.native_body != 237 or head_travel < 0.12)
