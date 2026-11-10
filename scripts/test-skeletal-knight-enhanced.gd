# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Fit := preload("bake-skeletal-knight-enhanced.gd")
const Visual := preload("res://Presentation/SourceEnhancedSkeletalMageVisual.gd")
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Body := 147
const Modes := {"0": {"8": ["SkeletalKnightSwordAlert"], "15": ["SkeletalKnightShieldRise"]}, "1": {}}
const Props := {"Scimitar": "cp_grasp_rhand", "WoodenShield": "cp_grasp_lhand"}


func run() -> void:
	var base := Registry.entry(Body)
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	var row := base.duplicate(true)
	row.assets = {}
	for treatment: String in Installed.registered_assets(base):
		row.assets[treatment] = Fit.Destination + "147-%s.scn" % treatment
	row.presentation_script = "res://Presentation/SourceEnhancedSkeletalMageVisual.gd"
	row.enhanced_source_action_groups = Modes
	row.archive_grounded_gestures = [Fit.Rise, Fit.Alert]
	if installed:
		row = Registry.entry(Body)
		assert(row.enhanced_source_action_groups == Modes)
	Registry.entries[Body] = row
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[Body] = {"serial": Body, "body": Body, "hue": 0x8035}
	var proof := {"terrain": 0, "falls": 0, "routes": 0, "classic": 0, "minimum_gap": INF, "maximum_jump": 0.0, "hashes": {}}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := create_actor(treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				var counts := check_routes(avatar, game, Body, Modes)
				proof.routes += counts.x
				proof.classic += counts.y
				proof.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
			for kind: int in [8, 15]:
				var packet := decode(game, Body, kind, 0)
				start_fit(actor, avatar, packet)
				for i in 31:
					move_to(actor, i / 30.0)
					var gap := minimum_gap(actor, floor)
					assert(gap >= .0019)
					proof.minimum_gap = minf(proof.minimum_gap, gap)
					for item: String in Props:
						assert(world_joint(actor, item.to_lower()).distance_to(world_joint(actor, Props[item])) < .00001)
					proof.terrain += 1
				for phase: float in [.11, .63]:
					start_fit(actor, avatar, packet)
					move_to(actor, phase)
					var jump := check_fall(actor, floor)
					proof.maximum_jump = maxf(proof.maximum_jump, jump)
					proof.falls += 1
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	Registry.entries[Body] = base
	game.free()
	print("SKELETAL KNIGHT RUNTIME ", proof)
	if not installed:
		var file := FileAccess.open(Fit.Destination + "skeletal-knight-runtime-receipt.json", FileAccess.WRITE)
		assert(file != null)
		proof.test_sha256 = FileAccess.get_sha256(get_script().resource_path)
		file.store_string(JSON.stringify(proof, "\t"))
		file.close()
	quit()


func create_actor(treatment: String) -> Node3D:
	var actor := Registry.create(Body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(Body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func start_fit(actor: Node3D, avatar: Avatar, packet: Dictionary) -> void:
	actor.animator.stop()
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	actor.animator.advance(.20)
	assert(Dispatch.dispatch(avatar, packet, true, 64))
	actor.animator.advance(.16)


func move_to(actor: Node3D, phase: float) -> void:
	actor.animator.seek(actor.animator.current_animation_length * phase, true)
	actor._physics_process(1.0 / 60.0)
	actor.contact.modification_processed.emit()
	actor.skeleton.force_update_all_bone_transforms()


func world_joint(actor: Node3D, name: String) -> Vector3:
	var rig: Skeleton3D = actor.skeleton
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(name)).origin)


func minimum_gap(actor: Node3D, floor: StaticBody3D) -> float:
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	return Ground.minimum_plane_gap(actor.gesture_skin, rig, rig.global_transform, floor.position, floor.basis.y)


func check_fall(actor: Node3D, floor: StaticBody3D) -> float:
	var fallen := create_actor(actor.treatment)
	fallen.global_transform = actor.global_transform
	fallen.model.transform = actor.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	var duration: float = fallen.begin_death_from(actor)
	var jump := 0.0
	for bone: String in ["bip01 head", "scimitar", "woodenshield"]:
		jump = maxf(jump, world_joint(actor, bone).distance_to(world_joint(fallen, bone)))
	assert(duration > 0.0 and jump < .002)
	for i in 31:
		fallen.animator.seek(duration * i / 30.0, true)
		assert(minimum_gap(fallen, floor) >= .0019)
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	for item: String in Props:
		assert(corpse.find_child(item, true, false) != null)
	corpse.free()
	fallen.free()
	return jump
