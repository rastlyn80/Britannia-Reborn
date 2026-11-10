# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Acid := preload("bake-acid-elemental-enhanced.gd")
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Body := 158
const Modes := {"0": {"8": ["AcidElementalSpatterGuard"], "15": ["AcidElementalCondense"]}, "1": {}}


func run() -> void:
	var base := Registry.entry(Body)
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	var row := base.duplicate(true)
	row.assets = {}
	for treatment: String in Installed.registered_assets(base):
		row.assets[treatment] = Acid.Destination + "158-%s.scn" % treatment
	row.enhanced_source_action_groups = Modes
	row.archive_grounded_gestures = Acid.Clips.values()
	if installed:
		row = Registry.entry(Body)
		assert(row.enhanced_source_action_groups == Modes)
	Registry.entries[Body] = row
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[Body] = {"serial": Body, "body": Body, "hue": 0x8035}
	var evidence := {"terrain_poses": 0, "interrupted_falls": 0, "size_recoveries": 0, "routes": 0,
		"classic": 0, "minimum_gap": INF, "largest_jump": 0.0, "hashes": {}}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := create_actor(row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				var counts := check_routes(avatar, game, Body, Modes)
				evidence.routes += counts.x
				evidence.classic += counts.y
				evidence.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
			for kind: int in [8, 15]:
				var action := decode(game, Body, kind, 0)
				start(actor, avatar, action)
				for i in 31:
					seek(actor, i / 30.0)
					var gap := plane_gap(actor, floor)
					assert(gap >= .0029, "%s %s %s %.7f" % [actor.current_clip, treatment, tilt, gap])
					evidence.minimum_gap = minf(evidence.minimum_gap, gap)
					evidence.terrain_poses += 1
				for phase: float in [.10, .58]:
					start(actor, avatar, action)
					seek(actor, phase)
					evidence.largest_jump = maxf(evidence.largest_jump, verify_fall(actor, row, floor))
					evidence.interrupted_falls += 1
			for use_attack: bool in [true, false]:
				start(actor, avatar, decode(game, Body, 15, 0))
				seek(actor, .11)
				var rig: Skeleton3D = actor.skeleton
				var bone := rig.find_bone("__root")
				assert(rig.get_bone_pose_scale(bone).length() < .50)
				if use_attack:
					assert(Classic.dispatch(avatar, {"protocol": "classic", "body": Body, "serial": Body,
						"action": 4, "frames": 5, "repeat_count": 1, "delay": 0}))
				else:
					actor.action_remaining = 0.0
					actor.play_gait(true, 1.5)
				for i in 21:
					actor.animator.advance(1.0 / 60.0)
				assert(rig.get_bone_pose_scale(bone).is_equal_approx(Vector3.ONE))
				evidence.size_recoveries += 1
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	game.free()
	Registry.entries[Body] = base
	print("ACID ELEMENTAL RUNTIME ", evidence)
	if not installed:
		var report := FileAccess.open(Acid.Destination + "acid-runtime-receipt.json", FileAccess.WRITE)
		assert(report != null)
		evidence.test_sha256 = FileAccess.get_sha256(get_script().resource_path)
		report.store_string(JSON.stringify(evidence, "\t"))
		report.close()
	quit()


func create_actor(row: Dictionary, treatment: String) -> Node3D:
	var actor: Node3D = Registry.create(Body) if Installed.enabled else load(Acid.Destination + "SourceEnhancedAcidElementalVisual.gd").new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(Body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func start(actor: Node3D, avatar: Avatar, action: Dictionary) -> void:
	actor.animator.stop()
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	actor.animator.advance(.20)
	assert(Dispatch.dispatch(avatar, action, true, 64))
	actor.animator.advance(.16)


func seek(actor: Node3D, phase: float) -> void:
	actor.animator.seek(actor.animator.current_animation_length * phase, true)
	actor._physics_process(1.0 / 60.0)
	actor.contact.modification_processed.emit()
	actor.skeleton.force_update_all_bone_transforms()


func plane_gap(actor: Node3D, floor: StaticBody3D) -> float:
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	return Ground.minimum_plane_gap(actor.support_skin, rig, rig.global_transform, floor.position, floor.basis.y)


func verify_fall(actor: Node3D, row: Dictionary, floor: StaticBody3D) -> float:
	var rig: Skeleton3D = actor.skeleton
	var joint := rig.find_bone("bip01 head")
	var start_head := rig.to_global(rig.get_bone_global_pose(joint).origin)
	var fall := create_actor(row, actor.treatment)
	fall.global_transform = actor.global_transform
	fall.model.transform = actor.model.transform
	fall.dead = true
	fall.contact.enabled = false
	var duration: float = fall.begin_death_from(actor)
	var end_rig: Skeleton3D = fall.skeleton
	var jump := start_head.distance_to(end_rig.to_global(end_rig.get_bone_global_pose(joint).origin))
	assert(duration > 0.0 and jump < .002, "Acid fall jumps %.7f" % jump)
	for i in 31:
		fall.animator.seek(duration * i / 30.0, true)
		assert(plane_gap(fall, floor) >= .0019)
	var snapshot := Snapshot.capture(fall, fall.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	corpse.free()
	fall.free()
	return jump
