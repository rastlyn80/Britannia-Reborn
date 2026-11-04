extends "res://../scripts/test-spider-mongbat-gestures.gd"

const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")
const BODY := 150
const ROUTES := {3: "Fidget", 4: "Fidget2", 5: "Attack", 6: "Attack2"}

func run() -> void:
	Registry.load_index()
	var sibling := Registry.entry(145).duplicate(true)
	if not "--active" in OS.get_cmdline_user_args():
		var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/sea_serpent_actions/candidates.json"))
		assert(not rows.is_empty())
		for row: Dictionary in rows:
			assert(int(row.body) == BODY and row.presentation == rows[0].presentation)
		Registry.entries[BODY] = rows[0].presentation
	var entry := Registry.entry(BODY)
	assert(entry.movement_mode == "native_waterline" and sibling.kind == "sea_serpents_sea_serpent")
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[SERIAL] = {"serial": SERIAL, "body": BODY, "hue": 0x8035}
	var deck := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(38.0, 0.1, 38.0)
	collider.shape = box
	deck.add_child(collider)
	deck.rotation.x = 0.09
	root.add_child(deck)
	for treatment: String in ["original", "rounded", "modern"]:
		assert(FileAccess.get_sha256(entry.assets[treatment]) == entry.authored_action_scene_sha256[treatment])
		var trial := entry.duplicate(true)
		trial.assets.modern = entry.assets[treatment]
		Registry.entries[BODY] = trial
		var avatar := Avatar.new()
		avatar.initial_body = BODY
		root.add_child(avatar)
		avatar.set_physics_process(false)
		var actor: Node3D = avatar.horse_visual
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.apply_identity(BODY, 0x8035)
		assert(actor.contact.feet.is_empty() and actor.native_hue == 0x8035)
		check_tracks(actor.animator, "res://local-art/creatures/sea_serpents_sea_serpent-%s.gltf" % treatment)
		for height: float in [-4.0, 0.35]:
			deck.position.y = height
			await physics_frame
			await physics_frame
			var motions := {}
			for slot: int in ROUTES:
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(SERIAL, 4))
				packet.append_array(PackedByteArray([0, slot, 0, 5, 0, 1, 1, 0, 0]))
				game._handle(packet)
				motions[slot] = sample_motion(avatar, game.last_mobile_actions[SERIAL], ROUTES[slot])
			print(treatment, " support ", height, " group min/max head Y, turn and jaw ", motions)
			assert(absf(motions[3].turn) < 1.2 and absf(motions[4].turn) > 5.8)
			assert(motions[6].low < -1.6 and motions[6].high > motions[5].high + 1.0 and motions[6].jaw > 0.46)
		avatar.free()
	Registry.entries[BODY] = entry
	assert(Registry.entry(145) == sibling and not sibling.get("classic_action_categories", {}).has("6"))
	for hue: int in [0x530, 0x8a0, 0x8035]:
		var corpse := Corpses.build(BODY, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("native_hue") == hue)
		assert(corpse.get_meta("death_clip") == "Death" and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
	deck.free()
	game.free()
	print("SEA SERPENT: 24 decoded actions at the native waterline, exact source keys and three corpse hues")
	quit()

func sample_motion(avatar: Node3D, packet: Dictionary, clip: String) -> Dictionary:
	var actor: Node3D = avatar.horse_visual
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var basis: Basis = actor.model.basis
	var head := rig.find_bone("bip01 head")
	var pelvis := rig.find_bone("bip01 pelvis")
	var jaw := rig.find_bone("serpent jaw")
	assert(head >= 0 and pelvis >= 0 and jaw >= 0)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.stop()
	actor.play("Idle", 0.0)
	player.advance(0.0)
	assert(avatar.receive_native_action(packet) and actor.current_clip == clip)
	var delta: float = actor.action_remaining / 48.0
	var result := {"low": INF, "high": -INF, "turn": 0.0, "jaw": 0.0}
	var previous_heading := 0.0
	var first_jaw := Quaternion.IDENTITY
	for frame in 49:
		player.advance(0.0 if frame == 0 else delta)
		avatar._physics_process(delta)
		actor._physics_process(delta)
		rig.force_update_all_bone_transforms()
		var bounds := Geometry.deformed_bounds(mesh, rig)
		assert(bounds.position.is_finite() and bounds.size.is_finite() and bounds.size.length() < 24.0)
		assert(avatar.global_position.is_zero_approx() and is_zero_approx(avatar.ground_offset))
		assert(actor.contact.contacts.is_empty() and actor.model.basis.is_equal_approx(basis))
		var point := rig.to_global(rig.get_bone_global_pose(head).origin)
		var forward := point - rig.to_global(rig.get_bone_global_pose(pelvis).origin)
		var heading := atan2(forward.x, forward.z)
		if frame == 0:
			first_jaw = rig.get_bone_pose_rotation(jaw)
		else:
			result.turn += wrapf(heading - previous_heading, -PI, PI)
		previous_heading = heading
		result.low = minf(result.low, point.y)
		result.high = maxf(result.high, point.y)
		result.jaw = maxf(result.jaw, first_jaw.angle_to(rig.get_bone_pose_rotation(jaw)))
	actor._process(actor.action_remaining + 0.001)
	avatar.animate(false, 0.0, 0.016, 0.0)
	assert(actor.current_clip == "Idle")
	return result
