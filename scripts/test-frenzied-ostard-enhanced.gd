# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Fit := preload("bake-frenzied-ostard-enhanced.gd")
const Profile := preload("res://Presentation/FrenziedOstardProfile.gd")
const Mounts := preload("res://Presentation/MountVisual.gd")
const BaseOstard := preload("res://Presentation/OstardMount.gd")
const Renderer := preload("res://Presentation/SourceEnhancedFrenziedOstardVisual.gd")
const PlayerAvatar := preload("res://Presentation/HumanAvatar.gd")
const Body := Profile.Body
const Hues := [0x8035, 0x455]
const Gear := [[], [{"id": 0x1f03}, {"id": 0x1539}, {"id": 0x170b}],
	[{"id": 0x1415}, {"id": 0x1410}, {"id": 0x1411}, {"id": 0x1414}, {"id": 0x170b}]]


static func source_routes() -> Dictionary:
	var clips := Fit.Gestures
	return {"0": {"2": [clips[15], clips[15]], "5": [clips[26], clips[27]], "8": [clips[28]],
		"11": [clips[4], clips[4], clips[4]], "14": [clips[25]], "15": [clips[23]]}, "1": {"5": [clips[26]]}}


static func fitted_row() -> Dictionary:
	var row := Profile.retained_row()
	row.enhanced_source_action_groups = source_routes()
	row.archive_grounded_gestures = Fit.Gestures.values()
	row.presentation_script = Profile.Renderer
	for treatment: String in row.assets:
		row.assets[treatment] = Fit.Destination + "%d-%s.scn" % [Body, treatment]
	return row


func run() -> void:
	assert(not Registry.supports_body(Body))
	var stock := Mounts.create(Body)
	assert(stock is BaseOstard and stock.kind == "frenzied")
	stock.free()
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	else:
		Registry.entries[Body] = fitted_row()
	var row := Registry.entry(Body)
	assert(row.get("presentation_script") == Profile.Renderer and row.enhanced_source_action_groups == source_routes())
	assert(Mounts.mount_available(Body, Profile.MountItem) and Mounts.horse_body(Profile.MountItem) == Body)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[Body] = {"serial": Body, "body": Body, "hue": Hues[0]}
	var report := {"poses": 0, "falls": 0, "routes": 0, "classic": 0, "mounted": 0, "loose_gaits": 0,
		"gap": INF, "fall_gap": INF, "handoff": 0.0, "seat_error": 0.0, "foot_error": 0.0, "mounted_gap": INF,
		"hashes": {}}
	var routes := source_routes()
	var packets := {}
	for kind: String in routes["0"]:
		var options: Array = routes["0"][kind]
		for variation in options.size():
			if not packets.has(options[variation]):
				packets[options[variation]] = decode(game, Body, int(kind), variation)
	for slope: Vector3 in Slopes:
		var floor := await create_floor(slope)
		for treatment: String in Profile.Treatments:
			var actor := create_actor(treatment, Hues[0])
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if slope == Vector3.ZERO:
				Giants.verify_base_clips(actor.animator, Fit.Source % treatment)
				var selections := check_routes(avatar, game, Body, routes)
				report.routes += selections.x
				report.classic += selections.y
				report.loose_gaits += check_loose_gaits(actor)
				report.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
			for clip: String in packets:
				start_action(avatar, packets[clip], clip)
				for sample in 25:
					seek(actor, sample / 24.0)
					var gap := minimum_gap(actor, floor, [actor.control_skin])
					assert(gap >= .0018, "%s support gap %.5f m" % [clip, gap])
					report.gap = minf(report.gap, gap)
					report.poses += 1
				for phase: float in [.21, .63]:
					start_action(avatar, packets[clip], clip)
					seek(actor, phase)
					var fall := check_fall(actor, floor)
					report.fall_gap = minf(report.fall_gap, fall.gap)
					report.handoff = maxf(report.handoff, fall.handoff)
					report.falls += 1
			avatar.free()
			actor.free()
		for gender: int in [400, 401]:
			for outfit: Array in Gear:
				await mounted_samples(floor, gender, outfit, report)
		floor.free()
		await physics_frame
	game.free()
	if not installed:
		Registry.entries.erase(Body)
	assert(report.poses == 2625 and report.falls == 210 and report.routes == 144 and report.classic == 108)
	assert(report.mounted == 360 and report.loose_gaits == 18)
	var receipt := FileAccess.open(Fit.Destination + "runtime-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify(report, "\t"))
	receipt.close()
	print("FRENZIED OSTARD RUNTIME ", report)
	quit()


func create_actor(treatment: String, hue: int) -> Node3D:
	var actor := Registry.create(Body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(Body, hue)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func check_loose_gaits(actor: Node3D) -> int:
	actor.action_remaining = 0.0
	for flags: int in [0, 64]:
		actor.set_native_combat_flags(flags)
		for stage in 3:
			actor.play_gait(stage > 0, [0.0, 2.0, 5.5][stage])
			var expected: String = Renderer.Quiet[stage] if flags == 0 else ["Idle", "Walk", "Run"][stage]
			assert(actor.current_clip == expected and actor.animator.get_animation(expected).loop_mode == Animation.LOOP_LINEAR)
	return 6


func check_fall(source: Node3D, floor: StaticBody3D) -> Dictionary:
	var fallen := create_actor(source.treatment, source.native_hue)
	fallen.global_transform = source.global_transform.rotated(Vector3.UP, .31)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	assert(fallen.begin_death_from(source) > 0.0)
	assert(fallen.current_clip == "Death" and not fallen.reins.visible)
	var jump := 0.0
	for joint: String in ["bip01 head", "bip01 spine1", "bip01 tail1", "bip01 r foot"]:
		jump = maxf(jump, landmark(source, joint).distance_to(landmark(fallen, joint)))
	assert(jump < .002, "Ostard death handoff moved %.6f m" % jump)
	var gap := INF
	for sample in 17:
		seek(fallen, sample / 16.0)
		gap = minf(gap, minimum_gap(fallen, floor, [fallen.control_skin]))
	assert(gap >= .0016)
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("corpse_body") == Body and corpse.get_meta("native_hue") == source.native_hue
		and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	corpse.free()
	fallen.free()
	return {"handoff": jump, "gap": gap}


func mounted_samples(floor: StaticBody3D, gender: int, outfit: Array, report: Dictionary) -> void:
	var rider := PlayerAvatar.new()
	rider.initial_body = gender
	root.add_child(rider)
	rider.set_physics_process(false)
	var worn := outfit.duplicate(true)
	var hue: int = Hues[gender - 400]
	worn.append({"id": Profile.MountItem, "layer": 25, "hue": hue})
	rider.apply_server_appearance({"body": gender, "hue": 1002}, worn)
	var mount: Node3D = rider.horse_visual
	assert(mount is Renderer and mount.native_body == Body and mount.native_mount_item == Profile.MountItem)
	assert(mount.native_hue == hue and rider.human_visual.missing_art.is_empty())
	rider.rider_contact.begin_mount(false)
	rider.human_visual.set_process(false)
	mount.set_process(false)
	mount.set_physics_process(false)
	mount.contact.active = false
	mount.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var anchor := rider.global_transform
	for stage in 3:
		mount.play_gait(stage > 0, [0.0, 2.0, 5.5][stage])
		var clip: String = Renderer.Seated[stage]
		assert(mount.current_clip == clip and mount.animator.get_animation(clip).loop_mode == Animation.LOOP_LINEAR)
		rider.human_visual.play(["Rider_Idle", "Rider_Walk", "Rider_Run"][stage], 0.0)
		mount.animator.advance(.20)
		for phase: float in [0.0, .25, .50, .75]:
			seek(mount, phase)
			rider.animator.seek(rider.animator.current_animation_length * phase, true)
			rider.animator.pause()
			mount._physics_process(1.0 / 60.0)
			if mount.contact.enabled:
				mount.contact._process_modification_with_delta(1.0 / 60.0)
				mount.contact.modification_processed.emit()
			for frame in 3:
				await process_frame
			var contact: SkeletonModifier3D = rider.rider_contact
			var feet: Array = contact.stirrup_errors
			assert(rider.global_transform == anchor and contact.seat_error < .002
				and feet.size() == 2 and feet[0] < .025 and feet[1] < .025, str([clip, gender, phase, contact.seat_error, feet]))
			assert(rider.human_visual.grip.reins_holding and rider.human_visual.grip.left_reins_holding)
			var gap := minimum_gap(mount, floor, [mount.control_skin])
			assert(gap >= -.003, "%s mounted ground gap %.6f" % [clip, gap])
			report.mounted_gap = minf(report.mounted_gap, gap)
			report.seat_error = maxf(report.seat_error, contact.seat_error)
			report.foot_error = maxf(report.foot_error, feet.max())
			report.mounted += 1
	rider.free()
