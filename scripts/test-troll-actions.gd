extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Test := preload("res://../scripts/test-quadruped-actions.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const SLOTS := {2: "Death2", 3: "Death", 4: "WideSwipe", 5: "Attack", 6: "RisingSweep",
	10: "Hit", 11: "KneelingSwing", 15: "OverheadGuard", 16: "ShoulderGuard", 17: "Fidget", 18: "KnuckleCheck"}

func _initialize() -> void:
	create_timer(40.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var samples := 0
	for body: int in [53, 54, 55]:
		var base := Registry.entry(body)
		var row := trial_row(body)
		Registry.entries[body] = row
		for treatment: String in row.assets:
			var source: String = base.get("classic_gesture_base_assets", base.assets)[treatment] if "--active" in OS.get_cmdline_user_args() else base.assets[treatment]
			witness(body, treatment, source)
			samples += SLOTS.size() * 81
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpses.build(body, hue)
			assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("native_hue") == hue)
			assert((corpse.find_child("Axe", true, false) != null) == (body == 53))
			assert((corpse.find_child("FrostClub", true, false) != null) == (body == 55))
			corpse.free()
	print("TROLL ACTIONS: ", samples, " decoded poses, rigid grips, three newer routes and nine static corpse hues")
	quit()

func witness(body: int, treatment: String, baseline: String) -> void:
	const SERIAL := 0x2020
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0x8035}
	var visual := Registry.create(body)
	visual.treatment = treatment
	root.add_child(visual)
	visual.apply_identity(body, 0x8035)
	visual.set_process(false)
	visual.set_physics_process(false)
	visual.contact.enabled = false
	var rig: Skeleton3D = visual.skeleton
	var player: AnimationPlayer = visual.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	Test.check_earlier_keys(player, baseline)
	var skins: Array[Dictionary] = []
	for mesh: MeshInstance3D in visual.model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			skins.append(Ground.skin_points(mesh, rig))
	var weapon := rig.find_bone("troll weapon")
	assert(skins.size() == (1 if body == 54 else 2) and (weapon < 0) == (body == 54))
	var grip: Transform3D
	if weapon >= 0:
		grip = rig.get_bone_pose(weapon)
	var start := visual.global_transform
	var traces := {}
	for slot: int in SLOTS:
		var packet := PackedByteArray([0x6e])
		packet.append_array(Wire.uint_be(SERIAL, 4))
		packet.append_array(PackedByteArray([0, slot, 0, 4, 0, 1, 1, 0, 0]))
		visual.dead = false
		player.stop()
		game._handle(packet)
		assert(visual.receive_action(game.last_mobile_actions[SERIAL]) and visual.current_clip == SLOTS[slot])
		player.advance(0.0)
		var minimum := INF
		var hand := rig.find_bone("bip01 r hand")
		var head := rig.find_bone("bip01 head")
		var trace := []
		for frame in 81:
			player.seek(player.current_animation_length * frame / 80.0, true)
			rig.force_update_all_bone_transforms()
			var gap := INF
			for skin: Dictionary in skins:
				gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
			assert(is_finite(gap) and visual.global_transform == start and visual.native_hue == 0x8035)
			if weapon >= 0 and slot in [2, 4, 6, 15, 16, 18]:
				assert(rig.get_bone_pose(weapon).is_equal_approx(grip))
			minimum = minf(gap, minimum)
			trace.append(rig.get_bone_global_pose(hand).origin - rig.get_bone_global_pose(head).origin)
		if slot in [2, 4, 6, 15, 16, 18]:
			assert(minimum > 0.002)
		traces[slot] = trace
		print("TROLL ", body, " ", treatment, " SLOT ", slot, " gap ", minimum)
	for pair: Array in [[2,3], [4,5], [4,6], [5,6], [10,15], [10,16], [15,16], [17,18]]:
		assert(traces[pair[0]] != traces[pair[1]])
	var newer := PackedByteArray([0xe2])
	newer.append_array(Wire.uint_be(SERIAL, 4))
	newer.append_array(PackedByteArray([0, 14, 0, 0, 0]))
	game._handle(newer)
	assert(visual.receive_action(game.last_mobile_actions[SERIAL]) and visual.current_clip == "KneelingSwing")
	game.free()
	visual.free()

static func trial_row(body: int) -> Dictionary:
	var row: Dictionary
	if "--active" in OS.get_cmdline_user_args():
		row = Registry.entry(body)
		assert(row.classic_gesture_batch == "troll_actions")
	else:
		var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../work/creatures/troll_actions/candidates.json"))
		var matching := candidates.filter(func(candidate: Dictionary) -> bool: return int(candidate.body) == body)
		assert(matching.size() == 1)
		row = matching[0].presentation
	for treatment: String in row.assets:
		assert(FileAccess.get_sha256(row.assets[treatment]) == row.authored_action_scene_sha256[treatment])
	assert(FileAccess.get_sha256(row.presentation_script) == row.presentation_script_sha256)
	return row
