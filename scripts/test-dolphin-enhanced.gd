# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-kraken-enhanced.gd"

const Dolphin := 151
const Scene := "res://../work/creatures/native-form-audit/enhanced-source-gaps/bird-ettin/dolphin-enhanced.scn"
const MotionCompare := preload("res://../scripts/test-quadruped-actions.gd")
const DolphinModes := {
	"0": {"2": ["DolphinHover", "DolphinHover"], "5": ["DolphinBank", "DolphinHover"],
		"8": ["DolphinHover"], "14": ["DolphinHover"], "15": ["DolphinHover"]},
	"1": {"5": ["DolphinBank"]},
}

func run() -> void:
	var base := Registry.entry(Dolphin)
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	var row := Registry.entry(Dolphin) if installed else base.duplicate(true)
	if not installed:
		row.assets.modern = Scene
		row.enhanced_source_action_groups = DolphinModes
	assert(row.enhanced_source_action_groups == DolphinModes)
	Registry.entries[Dolphin] = row
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[SERIAL] = {"serial": SERIAL, "body": Dolphin, "hue": 0x8035}
	var avatar := HumanAvatar.new()
	avatar.initial_body = Dolphin
	root.add_child(avatar)
	avatar.set_physics_process(false)
	var actor: Node3D = avatar.horse_visual
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.apply_identity(Dolphin, 0x8035)
	assert(actor.entry.movement_mode == "native_waterline" and actor.contact.feet.is_empty())
	MotionCompare.check_earlier_keys(actor.animator, Registry.asset_path(base))
	var selections := 0
	var comparisons := 0
	for flags: int in [0, 0x40]:
		for type: int in [2, 5, 8, 14, 15]:
			var options: Array = DolphinModes["1" if flags == 0 else "0"].get(str(type), DolphinModes["0"][str(type)])
			for variation: int in [0, 1, 2, 127]:
				assert(Profile.dispatch(avatar, decode(game, type, variation), true, flags))
				assert(actor.current_clip == options[variation % options.size()] and not actor.dead)
				selections += 1
			for variation: int in [0, 128, 255]:
				var packet := decode(game, type, variation)
				var accepted := Classic.dispatch(avatar, packet)
				var prior: String = actor.current_clip
				assert(Profile.dispatch(avatar, packet, variation > 0, flags) == accepted and actor.current_clip == prior)
				comparisons += 1
		assert(Profile.dispatch(avatar, decode(game, 11, 1), true, flags) and actor.current_clip == "Attack")
	var deck := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(35.0, .10, 35.0)
	collider.shape = box
	deck.add_child(collider)
	root.add_child(deck)
	var metrics := []
	for height: float in [-4.0, .35]:
		deck.position.y = height
		deck.rotation.z = .09
		await physics_frame
		await physics_frame
		metrics.append([measure_dolphin(avatar, decode(game, 5, 1), "DolphinHover"),
			measure_dolphin(avatar, decode(game, 5, 0), "DolphinBank")])
	assert(metrics[0] == metrics[1])
	assert(metrics[0][0] > .02 and metrics[0][0] < .08)
	assert(metrics[0][1] > .20 and metrics[0][1] < .35)
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(Dolphin, hue)
		assert(corpse != null and corpse.get_meta("corpse_body") == Dolphin and corpse.get_meta("native_hue") == hue)
		assert(corpse.get_meta("static_cadaver") and corpse.get_meta("graphic_id") == 0x2006)
		assert(corpse.find_children("*", "MeshInstance3D", true, false).size() == 6)
		corpse.free()
	Registry.entries[Dolphin] = base
	avatar.free()
	deck.free()
	game.free()
	assert(selections == 40 and comparisons == 30)
	if not installed:
		var file := FileAccess.open(Scene.get_base_dir() + "/dolphin-enhanced-candidate.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"routes": selections, "classic_comparisons": comparisons,
			"waterline_poses": 124, "corpse_hues": 3, "body_radians": metrics[0],
			"scene_sha256": {"modern": FileAccess.get_sha256(Scene)},
			"test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	print("DOLPHIN ENHANCED: ", selections, " selections, ", comparisons, " Classic comparisons, ",
		"124 waterline poses, three corpse hues; hover/bank body radians ", metrics[0])
	quit()

func measure_dolphin(avatar: Node3D, packet: Dictionary, expected: String) -> float:
	var actor: Node3D = avatar.horse_visual
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var body := rig.find_bone("body")
	var stable_model: Transform3D = actor.model.transform
	var stable_actor := avatar.global_position
	var meshes: Array[Node] = actor.model.find_children("*", "MeshInstance3D", true, false)
	assert(meshes.size() == 6 and rig.get_bone_count() == 9)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	assert(Profile.dispatch(avatar, packet, true, 0x40) and actor.current_clip == expected)
	player.advance(.13)
	player.seek(0.0, true)
	var first := rig.get_bone_pose_rotation(body)
	var angle := 0.0
	for frame in 31:
		player.seek(player.current_animation_length * frame / 30.0, true)
		avatar._physics_process(.01)
		actor._physics_process(.01)
		rig.force_update_all_bone_transforms()
		assert(avatar.global_position == stable_actor and is_zero_approx(avatar.ground_offset))
		assert(actor.contact.contacts.is_empty() and actor.model.transform.is_equal_approx(stable_model))
		var bounds := AABB()
		for mesh: MeshInstance3D in meshes:
			assert(mesh.skin != null)
			var part := Geometry.deformed_bounds(mesh, rig)
			assert(part.position.is_finite() and part.size.is_finite())
			bounds = part if mesh == meshes[0] else bounds.merge(part)
		assert(bounds.size.length() > 2.5 and bounds.size.length() < 5.0)
		angle = maxf(angle, first.angle_to(rig.get_bone_pose_rotation(body)))
	actor._process(actor.action_remaining + .001)
	avatar.animate(false, 0.0, .016, 0.0)
	assert(actor.current_clip == "Idle")
	return angle
