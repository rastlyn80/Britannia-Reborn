# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Batch := preload("bake-swamp-dragon-enhanced.gd")
const PlayerAvatar := preload("res://Presentation/Avatar.gd")
const Bodies := [794, 799]
const Inputs := {
	794: {1: [5, 0, 0], 4: [11, 0, 64], 11: [14, 0, 64], 15: [2, 0, 64], 23: [15, 0, 64],
		26: [5, 2, 0], 27: [5, 0, 64], 28: [8, 0, 64]},
	799: {11: [14, 0, 64], 12: [11, 0, 64], 15: [2, 0, 64], 23: [15, 0, 64], 26: [5, 0, 64],
		27: [5, 1, 64], 28: [8, 0, 64]},
}
var maximum_seat_error := 0.0
var maximum_foot_error := 0.0


static func modes_for(body: int) -> Dictionary:
	if body == 794:
		var clips := Batch.Loose
		return {"0": {"1": [clips[15], clips[15]], "2": [clips[15], clips[15]], "5": [clips[27]],
			"8": [clips[28]], "11": [clips[4], clips[4], clips[4]], "14": [clips[11]], "15": [clips[23]]},
			"1": {"5": [clips[1], clips[1], clips[26]]}}
	var clips := Batch.Barded
	return {"0": {"1": [clips[15], clips[15]], "2": [clips[15], clips[15]], "5": [clips[26], clips[27]],
		"8": [clips[28]], "11": [clips[12], clips[12], clips[12]], "14": [clips[11]], "15": [clips[23]]},
		"1": {"5": [clips[26]]}}


static func row_for(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	var clips: Dictionary = Batch.Loose if body == 794 else Batch.Barded
	row.presentation_script = "res://Presentation/SourceEnhancedSwampDragonVisual.gd"
	row.enhanced_source_action_groups = modes_for(body)
	row.enhanced_mounted_idle = clips[31]
	row.archive_grounded_gestures = clips.values()
	row.archive_grounded_gestures.erase(clips[31])
	for treatment: String in row.assets:
		row.assets[treatment] = Batch.Destination + "%d-%s.scn" % [body, treatment]
	return row


func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var bases := {}
	var report := {}
	var installed := "--installed" in OS.get_cmdline_user_args()
	for body: int in Bodies:
		bases[body] = Registry.entry(body)
	if installed:
		assert(Installed.enable())
	for body: int in Bodies:
		if not installed:
			Registry.entries[body] = row_for(body, bases[body])
		assert(Registry.entry(body).enhanced_source_action_groups == modes_for(body))
		report[str(body)] = {"poses": 0, "falls": 0, "gap": INF, "fall_gap": INF, "jump": 0.0,
			"routes": 0, "classic": 0, "rider_poses": 0, "hashes": {}}
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
	for slope: Vector3 in Slopes:
		var floor := await create_floor(slope)
		for body: int in Bodies:
			var row := Registry.entry(body)
			var counts: Dictionary = report[str(body)]
			for treatment: String in row.assets:
				sample_loose(game, floor, body, treatment, bases[body], counts, slope == Vector3.ZERO)
			for gender: int in [400, 401]:
				counts.rider_poses += await sample_seated(floor, body, gender)
		floor.free()
		await physics_frame
	for body: int in Bodies:
		var counts: Dictionary = report[str(body)]
		assert(counts.poses == Inputs[body].size() * 3 * Slopes.size() * 25)
		assert(counts.falls == Inputs[body].size() * 3 * Slopes.size() * 2)
		assert(counts.routes == 168 and counts.classic == 126 and counts.rider_poses == 130)
		print("SWAMP DRAGON ENHANCED ", body, " ", counts)
		Registry.entries[body] = bases[body]
	game.free()
	if not installed:
		var receipt := FileAccess.open(Batch.Destination + "swamp-runtime-receipt.json", FileAccess.WRITE)
		assert(receipt != null)
		receipt.store_string(JSON.stringify({"bodies": report, "seat_error": maximum_seat_error,
			"stirrup_error": maximum_foot_error}, "\t"))
		receipt.close()
	print("SWAMP DRAGON RIDERS seat ", maximum_seat_error, " stirrup ", maximum_foot_error)
	quit()


func dragon(body: int, treatment: String) -> Node3D:
	var actor := Registry.create(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func sample_loose(game: Node, floor: StaticBody3D, body: int, treatment: String, base: Dictionary, counts: Dictionary, flat: bool) -> void:
	var actor := dragon(body, treatment)
	var avatar := Avatar.new()
	avatar.horse_visual = actor
	var skins := body_skins(actor)
	var clips := Batch.Loose if body == 794 else Batch.Barded
	if flat:
		Batch.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
		var checks := check_routes(avatar, game, body, modes_for(body))
		counts.routes += checks.x
		counts.classic += checks.y
		counts.hashes[treatment] = FileAccess.get_sha256(actor.entry.assets[treatment])
		for group in [4, 9, 10, 11]:
			var packet := {"protocol": "classic", "action": group, "body": body}
			assert(Classic.dispatch(avatar, packet))
			assert(actor.current_clip == base.classic_action_categories[str(group)])
	for group: int in Inputs[body]:
		var selector: Array = Inputs[body][group]
		var request := decode(game, body, selector[0], selector[1])
		var clip: String = clips[group]
		start_swamp(avatar, request, clip, selector[2])
		for sample in 25:
			seek(actor, sample / 24.0)
			var gap := minimum_gap(actor, floor, skins)
			assert(gap >= .0012, "%d %s %s at %d has floor gap %.6f" % [body, treatment, clip, sample, gap])
			counts.gap = minf(counts.gap, gap)
			counts.poses += 1
		for phase: float in [.21, .61]:
			start_swamp(avatar, request, clip, selector[2])
			seek(actor, phase)
			var result := interrupted(actor, floor)
			counts.jump = maxf(counts.jump, result.jump)
			counts.fall_gap = minf(counts.fall_gap, result.gap)
			counts.falls += 1
	avatar.free()
	actor.free()


func start_swamp(avatar: Avatar, packet: Dictionary, clip: String, flags: int) -> void:
	var actor := avatar.horse_visual
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	actor.animator.advance(.22)
	assert(Dispatch.dispatch(avatar, packet, true, flags) and actor.current_clip == clip)
	actor.animator.advance(.16)


func interrupted(source: Node3D, floor: StaticBody3D) -> Dictionary:
	var fallen := dragon(source.native_body, source.treatment)
	fallen.global_transform = source.global_transform.rotated(Vector3.UP, -.31)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	assert(fallen.begin_death_from(source) > 0.0 and fallen.current_clip == "Death")
	var jump := 0.0
	for joint: String in ["bip01 head", "bip01 spine1", "bip01 l hand", "wing_r15"]:
		jump = maxf(jump, landmark(source, joint).distance_to(landmark(fallen, joint)))
	assert(jump < .002, "%s handoff displaced %.6f m" % [source.current_clip, jump])
	var gap := INF
	var skins := body_skins(fallen)
	for sample in 17:
		seek(fallen, sample / 16.0)
		gap = minf(gap, minimum_gap(fallen, floor, skins))
	assert(gap >= .0012, "%s fall has gap %.6f" % [source.current_clip, gap])
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	corpse.free()
	fallen.free()
	return {"jump": jump, "gap": gap}


func sample_seated(floor: StaticBody3D, body: int, gender: int) -> int:
	var rider := PlayerAvatar.new()
	root.add_child(rider)
	rider.set_physics_process(false)
	var item := int(Registry.entry(body).mount_item)
	rider.apply_server_appearance({"body": gender, "hue": 1002},
		[{"id": 0x1f03}, {"id": 0x170b}, {"id": item, "layer": 25, "hue": 53}])
	var mount: Node3D = rider.horse_visual
	assert(mount != null and mount.native_body == body and mount.native_mount_item == item and mount.native_hue == 53)
	rider.rider_contact.begin_mount(false)
	rider.human_visual.set_process(false)
	mount.set_physics_process(false)
	mount.contact.active = false
	mount.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	rider.human_visual.play("Rider_Idle", 0.0)
	var idle: String = mount.entry.enhanced_mounted_idle
	var anchor := rider.global_transform
	for speed: float in [1.9, 5.0]:
		mount.play_gait(true, speed)
		assert(mount.current_clip == ("Walk" if speed < 3.0 else "Run"))
	mount.play_gait(false, 0.0)
	assert(mount.current_clip == idle and mount.animator.get_animation(idle).loop_mode == Animation.LOOP_LINEAR)
	mount.animator.advance(.21)
	for sample in 13:
		seek(mount, sample / 13.0)
		mount._physics_process(1.0 / 60.0)
		mount.contact._process_modification_with_delta(1.0 / 60.0)
		mount.skeleton.force_update_all_bone_transforms()
		mount.contact.modification_processed.emit()
		assert(not mount.contact.contacts.is_empty())
		assert(mount.contact.contacts.values()[0].normal.dot(floor.global_basis.y.normalized()) > .999)
		for frame in 4:
			await process_frame
		var contact: SkeletonModifier3D = rider.rider_contact
		var feet: Array = contact.stirrup_errors
		assert(rider.global_transform == anchor and contact.seat_error < .002
			and feet.size() == 2 and feet[0] < .025 and feet[1] < .025,
			str([body, gender, sample, contact.seat_error, feet]))
		assert(rider.human_visual.grip.reins_holding and rider.human_visual.grip.left_reins_holding)
		maximum_seat_error = maxf(maximum_seat_error, contact.seat_error)
		maximum_foot_error = maxf(maximum_foot_error, feet.max())
	rider.free()
	return 13

