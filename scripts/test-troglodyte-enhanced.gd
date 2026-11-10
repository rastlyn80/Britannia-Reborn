# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-frost-through-gargoyle-actions.gd"

const BODY := 267
const SLOTS := {8: "TroglodyteOpenReach", 11: "TroglodyteHighSweep", 15: "TroglodyteLowRecoil"}
const PATTERN := "res://local-art/creatures/troglodyte-enhanced-%s.scn"
const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const Dispatcher := preload("res://Presentation/NativeMobileActions.gd")

class RouteAvatar extends Node3D:
	var horse_visual: Node3D
	func receive_native_action(request: Dictionary) -> bool:
		return horse_visual.receive_action(request)

func run() -> void:
	var row := Registry.entry(BODY).duplicate(true)
	var active := "--active" in OS.get_cmdline_user_args()
	assert(active == row.has("troglodyte_enhanced"))
	var originals: Dictionary = row.troglodyte_enhanced.source_assets if active else row.assets.duplicate()
	var index_digest := FileAccess.get_sha256("res://local-art/creatures/accepted-index.json")
	if active:
		for treatment: String in originals:
			assert(row.assets[treatment] == PATTERN % treatment)
			assert(row.asset_sha256[treatment] == FileAccess.get_sha256(row.assets[treatment]))
		for slot: int in SLOTS:
			assert(SLOTS[slot] in row.archive_grounded_gestures)
			assert(row.new_action_categories.get(str(slot), "") == ("" if slot == 8 else SLOTS[slot]))
	else:
		for treatment: String in originals:
			row.assets[treatment] = PATTERN % treatment
		row.archive_grounded_gestures.append_array(SLOTS.values())
		for slot: int in SLOTS:
			row.new_action_categories[str(slot)] = SLOTS[slot]
	Registry.entries[BODY] = row
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[BODY] = {"serial": BODY, "body": BODY, "hue": 53}
	var trials := 0
	var motions := {}
	for treatment: String in row.assets:
		var actor := Registry.create(BODY)
		actor.treatment = treatment
		root.add_child(actor)
		actor.apply_identity(BODY, 0x8035)
		actor.set_process(false)
		actor.set_physics_process(false)
		Exact.check_earlier_keys(actor.animator, originals[treatment])
		var avatar := RouteAvatar.new()
		avatar.horse_visual = actor
		for slot: int in SLOTS:
			var expected: String = "Pillage" if active and slot == 8 else SLOTS[slot]
			for variation in [0, 1, 2, 255]:
				assert(Dispatcher.dispatch(avatar, NewPacket.decode_new(game, BODY, slot, 0, variation)))
				assert(actor.current_clip == expected and actor.action_remaining > 0.0 and not actor.dead)
				trials += 1
		assert(actor.receive_action({"body": BODY, "protocol": "classic", "action": 4}))
		assert(actor.current_clip == "Attack")
		assert(actor.receive_action({"body": BODY, "protocol": "classic", "action": 11}))
		assert(actor.current_clip == "Pillage")
		assert(not actor.receive_action(NewPacket.decode_new(game, BODY, 5, 0, 0)))
		assert(Dispatcher.dispatch(avatar, NewPacket.decode_new(game, BODY, 5, 0, 0)) and actor.current_clip == "Fidget")
		assert(Dispatcher.dispatch(avatar, NewPacket.decode_new(game, BODY, 5, 0, 1)) and actor.current_clip == "TroglodyteSway")
		motions[treatment] = measure_motion(actor)
		avatar.free()
		actor.free()
	for hue: int in [0, 53, 0x8035]:
		var cadaver := Corpses.build(BODY, hue)
		assert(cadaver.get_meta("corpse_body") == BODY and cadaver.get_meta("native_hue") == hue)
		assert(cadaver.get_meta("static_cadaver") and cadaver.get_meta("death_clip") == "Death")
		assert(cadaver.find_children("*", "AnimationPlayer", true, false).is_empty())
		cadaver.free()
		static_corpses += 1
	game.free()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for treatment: String in row.assets:
			sample_ranked_ground(plane, BODY, treatment)
		plane.free()
		await physics_frame
	assert(trials == 36 and ground_poses == SLOPES.size() * row.assets.size() * row.archive_grounded_gestures.size() * 31)
	assert(static_corpses == 3 and lowest > .0004)
	assert(FileAccess.get_sha256("res://local-art/creatures/accepted-index.json") == index_digest)
	print("TROGLODYTE ENHANCED TRIAL: ", trials, " decoded selections, ", ground_poses, " grounded poses, ",
		static_corpses, " corpse hues, minimum gap ", lowest)
	print("TROGLODYTE ENHANCED MOTION: ", motions)
	if not active:
		var output := "res://../work/creatures/native-form-audit/enhanced-source-gaps/troglodyte-client.json"
		var file := FileAccess.open(output, FileAccess.WRITE)
		assert(file != null)
		var hashes := {}
		for treatment: String in row.assets:
			hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
		file.store_string(JSON.stringify({"test_sha256": FileAccess.get_sha256(get_script().resource_path),
			"scenes": hashes, "routes": trials, "terrain": ground_poses, "corpses": static_corpses,
			"minimum_gap": lowest, "motion": motions}))
		file.close()
	quit()

func measure_motion(actor: Node3D) -> Dictionary:
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	var result := {}
	for slot: int in SLOTS:
		player.stop()
		player.play(SLOTS[slot], 0.0)
		player.advance(0.0)
		var positions: Array[Vector3] = []
		var head: Array[float] = []
		for frame in 31:
			player.seek(player.current_animation_length * float(frame) / 30.0, true)
			rig.force_update_all_bone_transforms()
			head.append(joint(rig, "bip01 head").y)
			positions.append(joint(rig, "bip01 r hand"))
		var wrist_rise := positions[0].distance_to(positions[5])
		var hand_forward := positions[-1].z - positions[0].z
		var body_rise := float(head.max()) - float(head.min())
		if slot == 8:
			assert(hand_forward > .65 and body_rise > .17)
		elif slot == 11:
			assert(wrist_rise > .70 and body_rise > .60)
		else:
			assert(head[21] - head[0] > .70 and body_rise > .80)
		result[slot] = [body_rise, wrist_rise, hand_forward]
	return result

func joint(rig: Skeleton3D, label: String) -> Vector3:
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(label)).origin)
