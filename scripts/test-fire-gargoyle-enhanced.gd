# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Fire := preload("bake-fire-gargoyle-enhanced.gd")
const Renderer := "res://Presentation/SourceEnhancedFireGargoyleVisual.gd"
const Attack := preload("res://Presentation/EnhancedCreatureAttackActions.gd")
const BaseClips := {15: "FireGargoyleGuard", 23: "FireGargoyleRise", 26: "FireGargoyleRest",
	27: "FireGargoyleFlare", 28: "FireGargoyleRecoil"}
const AttackSubactions := [0, 1, 2, 9, 37, 0xffff, 0x101, 0x1ff]


static func source_routes() -> Dictionary:
	return {"0": {"2": [BaseClips[15], BaseClips[15]], "5": [BaseClips[26], BaseClips[27]],
		"8": [BaseClips[28]], "11": [Fire.Clips[4], Fire.Clips[4], Fire.Clips[4]],
		"14": [Fire.Clips[11]], "15": [BaseClips[23]]}, "1": {"5": [BaseClips[26]]}}


static func source_attacks() -> Dictionary:
	return {"0": [Fire.Clips[4], Fire.Clips[5], Fire.Clips[4]], "1": [Fire.Clips[4]],
		"2": [Fire.Clips[4]], "9": [Fire.Clips[4]],
		"255": [Fire.Clips[4], Fire.Clips[5], Fire.Clips[4], Fire.Clips[4], Fire.Clips[4], Fire.Clips[4]]}


static func fitted_row(base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.archive_grounded_gestures.append_array(Fire.Clips.values())
	row.enhanced_attack_subactions = source_attacks()
	row.enhanced_source_action_groups = source_routes()
	row.presentation_script = Renderer
	for treatment: String in row.assets:
		row.assets[treatment] = Fire.Destination + "130-%s.scn" % treatment
	return row


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): quit(2))
	call_deferred("run")


func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[Fire.Body] = {"serial": Fire.Body, "body": Fire.Body, "hue": 0}
	var base := Registry.entry(Fire.Body)
	var row := fitted_row(base)
	if "--installed" in OS.get_cmdline_user_args():
		assert(Installed.enable())
		row = Registry.entry(Fire.Body)
		assert(row.presentation_script == Renderer and row.enhanced_source_action_groups == source_routes())
		assert(row.enhanced_attack_subactions == source_attacks())
	var renderer := load(Renderer) as GDScript
	var checks := 0
	for treatment: String in base.assets:
		var actor := create_actor(renderer, row, treatment)
		var avatar := Avatar.new()
		avatar.horse_visual = actor
		actor.set_native_combat_flags(4)
		actor.play_gait(false, 0.0)
		assert(actor.current_clip == "Fly" and not actor.contact.enabled)
		assert(actor.animator.get_animation("Fly").loop_mode == Animation.LOOP_LINEAR)
		checks += 2
		for flags in [0, 64]:
			actor.set_native_combat_flags(flags)
			actor.action_remaining = 0.0
			actor.play_gait(true, 1.8)
			assert(actor.current_clip == ("Walk" if flags else "FireGargoylePeaceWalk"))
			actor.play_gait(false, 0.0)
			assert(actor.current_clip == ("Idle" if flags else "ReadyStance"))
			checks += 2
			for subaction in [0, 1, 2, 9, 37, 0x100, 0x101, 0x1ff]:
				for variant in range(8):
					var packet := decode(game, 0, subaction, variant)
					var table := source_attacks()
					var choices: Array = table.get(str(subaction & 0xff), table["255"])
					assert(Attack.dispatch(avatar, packet, true, flags))
					assert(actor.current_clip == choices[variant % choices.size()] and actor.get_meta("native_action") == packet)
					checks += 1
			for type in [2, 5, 8, 11, 14, 15]:
				for variant in range(4):
					var packet := decode(game, type, 0, variant)
					var table := source_routes()
					var groups: Dictionary = table["0" if flags else "1"]
					var choices: Array = groups.get(str(type), table["0"][str(type)])
					assert(Attack.dispatch(avatar, packet, true, flags))
					assert(actor.current_clip == choices[variant % choices.size()] and actor.get_meta("native_action") == packet)
					checks += 1
		var stock := classic_breath(game, 4)
		assert(Classic.dispatch(avatar, stock) and actor.current_clip == "Attack" and actor.fire_breath_origin() == null)
		var breath := classic_breath(game, 5)
		assert(Classic.dispatch(avatar, breath) and actor.current_clip == Fire.Clips[31])
		actor.animator.advance(1.3)
		assert(is_equal_approx(actor.animator.current_animation_position, 1.3))
		var muzzle: Variant = actor.fire_breath_origin()
		assert(muzzle is Vector3 and muzzle.is_finite())
		var bone: Vector3 = actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(actor.muzzle_head).origin)
		assert(muzzle.distance_to(bone) > .12 and muzzle.distance_to(bone) < .16)
		checks += 5
		avatar.free()
		actor.free()
	assert(checks == 561)
	var geometry := await check_ground_and_falls(renderer, row, game)
	assert(geometry.poses == 1860 and geometry.falls == 120 and geometry.fall_poses == 1320)
	geometry.routing = checks
	geometry.hashes = {}
	for treatment: String in row.assets:
		geometry.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
	var receipt := FileAccess.open(Fire.Destination + "runtime-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify(geometry, "\t"))
	receipt.close()
	print("FIRE GARGOYLE RUNTIME ", geometry)
	game.free()
	await process_frame
	quit()


func create_actor(renderer: GDScript, row: Dictionary, treatment: String) -> Node3D:
	var actor: Node3D = renderer.new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(Fire.Body, 0x8035)
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func check_ground_and_falls(renderer: GDScript, row: Dictionary, game: Node) -> Dictionary:
	var packets := {4: decode(game, 0, 0, 0), 5: decode(game, 0, 0, 1),
		11: decode(game, 14, 0, 0), 31: classic_breath(game, 5)}
	var report := {"poses": 0, "falls": 0, "fall_poses": 0, "gap": INF, "fall_gap": INF, "jump": 0.0}
	for slope: Vector3 in Slopes:
		var floor := await create_floor(slope)
		for treatment: String in row.assets:
			var actor := create_actor(renderer, row, treatment)
			actor.rotation.y = .19
			actor.set_native_combat_flags(64)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			for group: int in Fire.Clips:
				assert(Attack.dispatch(avatar, packets[group], true, 64))
				assert(actor.current_clip == Fire.Clips[group])
				actor.animator.advance(.14)
				for sample in 31:
					ground_pose(actor, sample / 30.0)
					var gap := minimum_gap(actor, floor, [actor.ground_gesture.skin])
					assert(gap >= .0016, "%s terrain clearance %.6f m" % [actor.current_clip, gap])
					report.gap = minf(report.gap, gap)
					report.poses += 1
				for phase: float in [.19, .67]:
					ground_pose(actor, phase)
					check_fall(renderer, row, actor, floor, report)
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	return report


func ground_pose(actor: Node3D, phase: float) -> void:
	seek(actor, phase)
	actor._physics_process(0.0)
	actor.contact.modification_processed.emit()
	actor.skeleton.force_update_all_bone_transforms()


func check_fall(renderer: GDScript, row: Dictionary, source: Node3D, floor: StaticBody3D, report: Dictionary) -> void:
	var fallen := create_actor(renderer, row, source.treatment)
	fallen.global_transform = source.global_transform.rotated(Vector3.UP, .31)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	assert(fallen.begin_death_from(source) > 0.0 and fallen.current_clip == "Death")
	var jump := 0.0
	for joint: String in ["bip01 head", "bip01 l hand", "bip01 r hand", "gargoyle r wing3"]:
		jump = maxf(jump, landmark(source, joint).distance_to(landmark(fallen, joint)))
	assert(jump < .002, "%s collapse moved %.6f m" % [source.current_clip, jump])
	report.jump = maxf(report.jump, jump)
	for sample in 11:
		seek(fallen, sample / 10.0)
		var gap := minimum_gap(fallen, floor, [fallen.fall.skin])
		assert(gap >= .0016, "%s collapse clearance %.6f m" % [source.current_clip, gap])
		report.fall_gap = minf(report.fall_gap, gap)
		report.fall_poses += 1
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.get_meta("corpse_body") == Fire.Body)
	assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	corpse.free()
	fallen.free()
	report.falls += 1


func decode(game: Node, type: int, subaction: int, variant: int) -> Dictionary:
	var packet := PackedByteArray([0xe2])
	packet.append_array(Wire.uint_be(Fire.Body, 4))
	packet.append_array(Wire.uint_be(type, 2))
	packet.append_array(Wire.uint_be(subaction, 2))
	packet.append(variant)
	game._handle(packet)
	return game.last_mobile_actions[Fire.Body]


func classic_breath(game: Node, frames: int) -> Dictionary:
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(Fire.Body, 4))
	packet.append_array(PackedByteArray([0, 12, 0, frames, 0, 1, 0, 0, 0]))
	game._handle(packet)
	return game.last_mobile_actions[Fire.Body]
