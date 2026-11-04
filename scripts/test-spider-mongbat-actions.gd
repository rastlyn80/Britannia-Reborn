extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Corpse := preload("res://Presentation/CorpseModels.gd")
const BODIES := [28, 39]
const NEW_CLIPS := ["Death2", "FrontClasp", "ForwardStab", "LegFlick", "SpiderBrace", "AbdomenRock",
	"WingBackhand", "WingJab", "WingOpenRecoil", "WingFoldRecoil"]

func _initialize() -> void:
	create_timer(25.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	const SERIAL := 0x2010
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var samples := 0
	for body: int in BODIES:
		var base := Registry.entry(body)
		var row := trial_row(body)
		var treatments: Array = row.assets.keys()
		Registry.entries[body] = row
		game.entities[SERIAL] = {"serial": SERIAL, "body": body, "hue": 0x8035}
		for treatment: String in treatments:
			var visual := Registry.create(body)
			visual.treatment = treatment
			root.add_child(visual)
			visual.apply_identity(body, 0x8035)
			visual.set_process(false)
			visual.set_physics_process(false)
			var player: AnimationPlayer = visual.animator
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var source: String = base.classic_gesture_base_assets[treatment] if "--active" in OS.get_cmdline_user_args() else Registry.asset_path(base, treatment)
			Exact.check_earlier_keys(player, source)
			var rig: Skeleton3D = visual.skeleton
			var mesh := visual.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
			var skin := Ground.skin_points(mesh, rig)
			var anchor := visual.global_transform
			var centre := rig.find_bone("bone01" if body == 28 else "bip01")
			for key: String in row.classic_action_categories:
				var slot := int(key)
				var expected: String = row.classic_action_categories[key]
				var frames := int(row.classic_motion_references[key].frames)
				visual.dead = false
				player.stop()
				var packet := PackedByteArray([0x6e])
				packet.append_array(Wire.uint_be(SERIAL, 4))
				packet.append_array(PackedByteArray([0, slot, 0, frames, 0, 1, 1, 0, 0]))
				game._handle(packet)
				assert(visual.receive_action(game.last_mobile_actions[SERIAL]) and visual.current_clip == expected)
				player.play(visual.current_clip, 0.0)
				player.advance(0.0)
				var minimum := INF
				for frame in 65:
					player.seek(player.current_animation_length * frame / 64.0, true)
					rig.force_update_all_bone_transforms()
					var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
					assert(is_finite(gap) and visual.global_transform == anchor and visual.native_hue == 0x8035)
					minimum = minf(minimum, gap)
					samples += 1
				if expected in NEW_CLIPS:
					assert(minimum > -0.004, "Body %d group %d minimum %f" % [body, slot, minimum])
				if slot in [2, 3, 21]:
					print(body, " ", treatment, " slot ", slot, " gap ", minimum, " final trunk ",
						rig.to_global(rig.get_bone_global_pose(centre).origin))
					if slot == 3:
						assert(rig.to_global(rig.get_bone_global_pose(centre).origin).y < 0.8)
			if body == 39:
				visual.dead = false
				var packet := PackedByteArray([0xe2])
				packet.append_array(Wire.uint_be(SERIAL, 4))
				packet.append_array(PackedByteArray([0, 14, 0, 0, 0]))
				game._handle(packet)
				assert(visual.receive_action(game.last_mobile_actions[SERIAL]) and visual.current_clip == "WingSettle")
			visual.free()
		for hue: int in [0, 53, 0x8035]:
			var corpse := Corpse.build(body, hue)
			assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("native_hue") == hue)
			corpse.free()
	game.free()
	print("MONGBAT AND GIANT SPIDER: ", samples, " decoded poses, exact prior keys, roots and raw hues")
	quit()

static func trial_row(body: int) -> Dictionary:
	var row: Dictionary
	if "--active" in OS.get_cmdline_user_args():
		row = Registry.entry(body)
		assert(row.classic_gesture_batch == "spider_mongbat_actions")
	else:
		var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string(
			"res://../work/creatures/spider_mongbat_actions/candidates.json"))
		var matching := candidates.filter(func(candidate: Dictionary) -> bool: return int(candidate.body) == body)
		assert(not matching.is_empty())
		row = matching[0].presentation
		assert(matching.all(func(candidate: Dictionary) -> bool: return candidate.presentation == row))
	for treatment: String in row.assets:
		assert(FileAccess.get_sha256(row.assets[treatment]) == row.authored_action_scene_sha256[treatment])
	assert(FileAccess.get_sha256(row.presentation_script) == row.presentation_script_sha256)
	return row
