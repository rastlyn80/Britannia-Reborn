extends "res://../scripts/test-spider-mongbat-gestures.gd"

const BODY := 39
const ROUTES := {17: "MongbatArmLift", 18: "Fidget2"}

func run() -> void:
	Registry.load_index()
	if not "--active" in OS.get_cmdline_user_args():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/mongbat_fidgets/candidates.json"))
		assert(not rows.is_empty())
		for row: Dictionary in rows:
			assert(int(row.body) == BODY and row.presentation == rows[0].presentation)
		Registry.entries[BODY] = rows[0].presentation
	var entry := Registry.entry(BODY)
	assert(entry.classic_action_categories["11"] == "WingSettle")
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[SERIAL] = {"serial": SERIAL, "body": BODY, "hue": 0x8035}
	var plane := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 0.1, 8.0)
	collider.shape = box
	collider.position.y = -0.05
	plane.add_child(collider)
	root.add_child(plane)
	for treatment: String in ["original", "rounded", "modern"]:
		assert(FileAccess.get_sha256(entry.assets[treatment]) == entry.authored_action_scene_sha256[treatment])
		var actor := Registry.create(BODY)
		actor.treatment = treatment
		root.add_child(actor)
		actor.apply_identity(BODY, 0x8035)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		check_tracks(actor.animator, "res://local-art/creatures/mul-gesture-39-%s.scn" % treatment)
		check_source_alpha(actor, treatment, entry.source_alpha_texture)
		for tilt: Vector3 in [Vector3.ZERO, Vector3(0.08, 0.0, -0.08), Vector3(-0.09, 0.0, 0.11)]:
			plane.rotation = tilt
			await physics_frame
			await physics_frame
			for slot: int in ROUTES:
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(SERIAL, 4))
				packet.append_array(PackedByteArray([0, slot, 0, 5, 0, 1, 1, 0, 0]))
				game._handle(packet)
				assert(check_fidget(actor, plane, ROUTES[slot], game.last_mobile_actions[SERIAL]))
		actor.free()
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(BODY, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("native_hue") == hue)
		assert(corpse.get_meta("death_clip") == "Death" and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
	game.free()
	plane.free()
	print("MONGBAT: 18 decoded terrain fidgets, retained source and WingSettle keys, three static corpse hues")
	quit()

func check_fidget(actor: Node3D, plane: StaticBody3D, clip: String, packet: Dictionary) -> bool:
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var hand := rig.find_bone("bip01 l hand")
	var head := rig.find_bone("bip01 head")
	var wings := [rig.find_bone("mongbat l wingfinger1b"), rig.find_bone("mongbat r wingfinger1b")]
	assert(hand >= 0 and head >= 0 and not wings.has(-1))
	var native_root := actor.global_transform
	player.stop()
	actor.play("Idle", 0.0)
	player.advance(0.0)
	for frame in 60:
		actor._physics_process(1.0 / 60.0)
	assert(actor.receive_action(packet) and actor.current_clip == clip and actor.native_hue == 0x8035)
	var duration: float = actor.action_remaining
	var delta := duration / 48.0
	var gap := INF
	var reach := -INF
	var lift := 0.0
	for frame in 49:
		player.advance(0.0 if frame == 0 else delta)
		actor._physics_process(delta)
		actor.contact._process_modification_with_delta(delta)
		rig.force_update_all_bone_transforms()
		actor.contact.modification_processed.emit()
		assert(not actor.contact.contacts.is_empty() and actor.global_transform.is_equal_approx(native_root))
		if delta * frame >= 0.15:
			for wing: int in wings:
				var tip := rig.to_global(rig.get_bone_global_pose(wing).origin)
				assert(absf(tip.x) < 0.8 and tip.z < -1.0)
		var wrist := rig.to_global(rig.get_bone_global_pose(hand).origin)
		var skull := rig.to_global(rig.get_bone_global_pose(head).origin)
		reach = maxf(reach, wrist.y - skull.y)
		gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.position, plane.basis.y))
		lift = maxf(lift, actor.gesture_lift)
	actor._process(duration + 0.001)
	actor.play_gait(false, 0.0)
	actor._physics_process(delta)
	assert(actor.current_clip == "Idle" and actor.gesture_lift == 0.0)
	print(actor.treatment, " ", clip, " ", plane.rotation, " floor, wrist above skull, lift ", [gap, reach, lift])
	return gap >= -0.005 and lift < 0.07 and (reach > 0.25 if clip == ROUTES[18] else reach < -0.30)
