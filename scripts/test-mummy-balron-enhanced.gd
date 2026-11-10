# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Fit := preload("bake-mummy-balron-enhanced.gd")
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const NativeHue := preload("res://Presentation/HumanHue.gd")
const SourceModes := {
	154: {"0": {"8": ["MummyRaisedArmsAlert"], "11": ["MummyOverheadRecoil", "MummyOverheadRecoil", "MummyOverheadRecoil"],
		"15": ["MummyCrouchedRise"]}, "1": {}},
	40: {"0": {"5": ["BalronWingWatch", "BalronWingbeatRecoil"], "8": ["BalronWideThreat"],
		"15": ["BalronWingCocoonRise"]}, "1": {"5": ["BalronWingWatch"]}},
}


func run() -> void:
	var installed := "--installed" in OS.get_cmdline_user_args()
	var base := {}
	for body: int in SourceModes:
		base[body] = Registry.entry(body)
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var proof := {}
	for body: int in SourceModes:
		var row := Registry.entry(body) if installed else candidate_row(body, base[body])
		assert(row.enhanced_source_action_groups == SourceModes[body])
		Registry.entries[body] = row
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		var result := await review_body(game, body, row)
		assert(result.has("routes"))
		proof[str(body)] = result
		Registry.entries[body] = base[body]
	game.free()
	if not installed:
		var report := FileAccess.open(Fit.Destination + "terrain-receipt.json", FileAccess.WRITE)
		assert(report != null)
		report.store_string(JSON.stringify({"bodies": proof, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		report.close()
	quit()


static func candidate_row(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.assets = {}
	for treatment: String in Installed.registered_assets(base):
		row.assets[treatment] = Fit.Destination + "%d-%s.scn" % [body, treatment]
	row.enhanced_source_action_groups = SourceModes[body]
	row.archive_grounded_gestures = (Fit.MummyClips if body == 154 else Fit.BalronClips).values()
	row.presentation_script = "res://Presentation/" + (
		"SourceEnhancedMummyVisual.gd" if body == 154 else "SourceEnhancedBalronVisual.gd"
	)
	if body == 40:
		row.flight_falls_back_to_combat = true
	return row


func create_actor(body: int, row: Dictionary, treatment: String) -> Node3D:
	var actor: Node3D = Registry.create(body) if Installed.enabled else load(Fit.Destination + row.presentation_script.get_file()).new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func review_body(game: Node, body: int, row: Dictionary) -> Dictionary:
	var proof := {"poses": 0, "falls": 0, "routes": 0, "classic": 0, "gap": INF, "jump": 0.0,
		"air_poses": 0, "air_falls": 0, "air_gap": 0.0, "air_choices": 0, "hashes": {}}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := create_actor(body, row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				var counts := check_routes(avatar, game, body, SourceModes[body])
				proof.routes += counts.x
				proof.classic += counts.y
				proof.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				if treatment == "modern":
					check_dyes(actor)
			for kind: String in SourceModes[body]["0"]:
				var choices: Array = SourceModes[body]["0"][kind]
				for variation in choices.size():
					var clip: String = choices[variation]
					if choices.find(clip) != variation:
						continue
					var packet := decode(game, body, int(kind), variation)
					start_action(actor, avatar, packet, clip)
					for index in 31:
						sample_pose(actor, index / 30.0)
						var gap := gap_to_plane(actor, floor)
						assert(gap >= .0018, "%d %s phase %.3f gap %.7f" % [body, clip, index / 30.0, gap])
						proof.gap = minf(proof.gap, gap)
						proof.poses += 1
					for phase: float in [.18, .49]:
						start_action(actor, avatar, packet, clip)
						sample_pose(actor, phase)
						proof.jump = maxf(proof.jump, check_handoff(actor, row, floor))
						proof.falls += 1
					if body == 40:
						check_air(actor, avatar, row, packet, clip, floor, proof)
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	print("MUMMY AND BALRON RUNTIME ", body, " ", proof)
	return proof


func check_dyes(actor: Node3D) -> void:
	var mesh := actor.model.find_child("Body", true, false) as MeshInstance3D
	for hue: int in [0, 0x455, 0x8035]:
		actor.apply_identity(actor.native_body, hue)
		var shell := mesh.get_active_material(0) as ShaderMaterial
		assert(shell.get_shader_parameter("hue_palette") == NativeHue.palette(hue))
		assert(shell.get_shader_parameter("use_hue") == (hue != 0))
		assert(shell.get_shader_parameter("partial_hue") == ((hue & 0x8000) != 0))


func start_action(actor: Node3D, avatar: Avatar, packet: Dictionary, clip: String, flags := 64) -> void:
	actor.animator.stop()
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	actor.animator.advance(.20)
	if actor.native_body == 40:
		actor.set_native_combat_flags(flags)
	assert(Dispatch.dispatch(avatar, packet, true, flags) and actor.current_clip == clip)
	actor.animator.advance(.15)


func check_air(actor: Node3D, avatar: Avatar, row: Dictionary, packet: Dictionary, clip: String,
		floor: StaticBody3D, proof: Dictionary) -> void:
	# No combat bit. The archived flight mode must still choose the combat list.
	start_action(actor, avatar, packet, clip, 4)
	assert(actor.airborne_fit and not actor.contact.enabled)
	proof.air_choices += 1
	for index in range(5, 31):
		sample_pose(actor, index / 30.0)
		var gap := gap_to_plane(actor, floor)
		assert(gap >= .6498, "%s air support %.6f" % [clip, gap])
		proof.air_gap = minf(proof.air_gap, gap) if proof.air_poses > 0 else gap
		proof.air_poses += 1
	for phase: float in [.19, .62]:
		start_action(actor, avatar, packet, clip, 4)
		sample_pose(actor, phase)
		proof.jump = maxf(proof.jump, check_handoff(actor, row, floor, true))
		proof.air_falls += 1


func sample_pose(actor: Node3D, phase: float) -> void:
	actor.animator.seek(actor.animator.current_animation_length * phase, true)
	actor._physics_process(1.0 / 60.0)
	actor.contact._process_modification_with_delta(1.0 / 60.0)
	actor.contact.modification_processed.emit()
	actor.skeleton.force_update_all_bone_transforms()


func joint_position(actor: Node3D, joint: String) -> Vector3:
	var rig: Skeleton3D = actor.skeleton
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(joint)).origin)


func gap_to_plane(actor: Node3D, floor: StaticBody3D) -> float:
	var rig: Skeleton3D = actor.skeleton
	return Ground.minimum_plane_gap(actor.fitted_fall.skin, rig, rig.global_transform, floor.position, floor.basis.y)


func check_handoff(source: Node3D, row: Dictionary, floor: StaticBody3D, airborne := false) -> float:
	var body: int = source.native_body
	var fallen := create_actor(body, row, source.treatment)
	fallen.global_transform = source.global_transform
	fallen.rotate_y(.29)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	var duration: float = fallen.begin_death_from(source)
	assert(fallen.current_clip == ("AirDeath" if airborne else "Death"))
	var joints := ["bip01 head", "daemon l wing03", "daemon r wing03", "bip01 r foot"] if body == 40 else ["bip01 head", "bip01 r hand", "bip01 l foot"]
	var jump := 0.0
	for joint: String in joints:
		jump = maxf(jump, joint_position(source, joint).distance_to(joint_position(fallen, joint)))
	assert(duration > 0 and jump < .002, "%d %s displayed fall jump %.7f" % [body, source.current_clip, jump])
	for index in 31:
		fallen.animator.seek(duration * index / 30.0, true)
		assert(gap_to_plane(fallen, floor) >= .0018)
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	corpse.free()
	fallen.free()
	return jump
