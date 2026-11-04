extends "res://../scripts/test-spider-mongbat-gestures.gd"

const STEMS := {17: "orcs_orc", 18: "ettins_ettin"}
const ROUTES := {15: "RightRecoil", 16: "LeftRecoil"}

func run() -> void:
	Registry.load_index()
	var active := "--active" in OS.get_cmdline_user_args()
	var candidates: Array = []
	if not active:
		candidates = JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/orc_ettin_reactions/candidates.json"))
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var plane := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12.0, 0.1, 12.0)
	collider.shape = box
	collider.position.y = -0.05
	plane.add_child(collider)
	root.add_child(plane)
	for body: int in STEMS:
		if not active:
			var rows := candidates.filter(func(item: Dictionary) -> bool: return int(item.body) == body)
			assert(rows.size() == 1)
			Registry.entries[body] = rows[0].presentation
		var entry := Registry.entry(body)
		assert(entry.classic_action_categories["18"] == "Fidget2")
		game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0x8035}
		for treatment: String in ["original", "rounded", "modern"]:
			assert(FileAccess.get_sha256(entry.assets[treatment]) == entry.authored_action_scene_sha256[treatment])
			var actor := Registry.create(body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			check_tracks(actor.animator, "res://local-art/creatures/%s-fidgets-%s.scn" % [STEMS[body], treatment])
			for tilt: Vector3 in [Vector3.ZERO, Vector3(0.08, 0.0, -0.08), Vector3(-0.09, 0.0, 0.11)]:
				plane.rotation = tilt
				await physics_frame
				await physics_frame
				for slot: int in ROUTES:
					var packet := PackedByteArray([0x6e])
					packet.append_array(Wire.uint_be(SERIAL, 4))
					packet.append_array(PackedByteArray([0, slot, 0, 3, 0, 1, 1, 0, 0]))
					game._handle(packet)
					assert(sample_recoil(actor, plane, ROUTES[slot], game.last_mobile_actions[SERIAL]))
			actor.free()
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("native_hue") == hue)
			assert(corpse.get_meta("death_clip") == "Death" and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
			corpse.free()
	game.free()
	plane.free()
	print("ORC AND ETTIN: 36 decoded terrain reactions, unchanged source and fidget tracks, six corpse hues")
	quit()

func sample_recoil(actor: Node3D, plane: StaticBody3D, clip: String, packet: Dictionary) -> bool:
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var head_names := ["bip01 head"] if actor.native_body == 17 else ["geosphere01", "geosphere02"]
	var right := clip == "RightRecoil"
	var hand := rig.find_bone("bip01 r hand" if right else "bip01 l hand")
	var native_root := actor.global_transform
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.stop()
	actor.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 60:
		actor._physics_process(1.0 / 60.0)
	assert(actor.receive_action(packet) and actor.current_clip == clip)
	var duration: float = actor.action_remaining
	var delta := duration / 48.0
	var gap := INF
	var offset := Vector3.ZERO
	for frame in 49:
		player.advance(0.0 if frame == 0 else delta)
		actor._physics_process(delta)
		actor.contact._process_modification_with_delta(delta)
		rig.force_update_all_bone_transforms()
		actor.contact.modification_processed.emit()
		assert(actor.global_transform.is_equal_approx(native_root) and not actor.contact.contacts.is_empty())
		gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.position, plane.basis.y))
		if frame == 24:
			var head := Vector3.ZERO
			for name: String in head_names:
				head += rig.to_global(rig.get_bone_global_pose(rig.find_bone(name)).origin)
			offset = rig.to_global(rig.get_bone_global_pose(hand).origin) - head / float(head_names.size())
	actor._process(duration + 0.001)
	actor.play_gait(false, 0.0)
	assert(actor.current_clip == "Idle" and actor.native_hue == 0x8035)
	print(actor.native_body, " ", actor.treatment, " ", clip, " ", plane.rotation, " floor ", gap, " active wrist offset ", offset)
	return gap > -0.020 and (offset.y > -0.08 if right else offset.y < -0.12) and offset.z > 0.22
