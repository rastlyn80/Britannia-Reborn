# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Giants := preload("bake-cyclops-titan-enhanced.gd")
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const PreviewRenderers := {75: "SourceEnhancedCyclopsVisual.gd", 76: "SourceEnhancedTitanVisual.gd"}


static func source_modes(body: int) -> Dictionary:
	var clips: Dictionary = Giants.Clips[body]
	return {"0": {"5": [clips[26], clips[27]], "8": [clips[28]], "11": [clips[4], clips[4], clips[4]],
		"15": [clips[23]]}, "1": {"5": [clips[26]]}}


static func candidate_row(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	for variant: String in row.assets:
		row.assets[variant] = Giants.Destination + "%d-%s.scn" % [body, variant]
	row.enhanced_source_action_groups = source_modes(body)
	row.archive_grounded_gestures = Giants.Clips[body].values()
	return row


func run() -> void:
	var installed := "--installed" in OS.get_cmdline_user_args()
	var bases := {}
	for body: int in Giants.Clips:
		bases[body] = Registry.entry(body)
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var result := {}
	for body: int in Giants.Clips:
		var base: Dictionary = bases[body]
		var row := Registry.entry(body) if installed else candidate_row(body, base)
		assert(row.enhanced_source_action_groups == source_modes(body))
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		result[str(body)] = await review_giant(game, body, base, row)
		assert(result[str(body)].poses == 2325 and result[str(body)].falls == 150)
	game.free()
	if not installed:
		var file := FileAccess.open(Giants.Destination + "terrain-receipt.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"bodies": result, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	quit()


func actor_for(body: int, row: Dictionary, treatment: String) -> Node3D:
	var actor: Node3D
	if Installed.enabled:
		actor = Registry.create(body)
	else:
		var renderer := load(Giants.Destination + PreviewRenderers[body]) as GDScript
		actor = renderer.new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func review_giant(game: Node, body: int, base: Dictionary, row: Dictionary) -> Dictionary:
	var report := {"poses": 0, "falls": 0, "gap": INF, "fall_gap": INF, "jump": 0.0, "routes": 0, "classic": 0, "hashes": {}}
	var modes := source_modes(body)
	var packets := {}
	for kind: String in modes["0"]:
		var clips: Array = modes["0"][kind]
		for variation in clips.size():
			if not packets.has(clips[variation]):
				packets[clips[variation]] = decode(game, body, int(kind), variation)
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for variant: String in row.assets:
			var actor := actor_for(body, row, variant)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			var skins := body_skins(actor)
			if tilt == Vector3.ZERO:
				Giants.verify_base_clips(actor.animator, Registry.asset_path(base, variant))
				var counts := check_routes(avatar, game, body, modes)
				report.routes += counts.x
				report.classic += counts.y
				report.hashes[variant] = FileAccess.get_sha256(row.assets[variant])
			for clip: String in packets:
				start_action(avatar, packets[clip], clip)
				for sample in 31:
					seek(actor, sample / 30.0)
					var gap := minimum_gap(actor, floor, skins)
					assert(gap >= .0018, "%d %s %.2f support gap %.6f" % [body, clip, sample / 30.0, gap])
					report.gap = minf(report.gap, gap)
					report.poses += 1
				for phase: float in [.19, .67]:
					start_action(avatar, packets[clip], clip)
					seek(actor, phase)
					var result := check_giant_fall(actor, floor, body, row)
					report.jump = maxf(report.jump, result.jump)
					report.fall_gap = minf(report.fall_gap, result.gap)
					report.falls += 1
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	print("CYCLOPS AND TITAN RUNTIME ", body, " ", report)
	return report


func start_action(avatar: Avatar, packet: Dictionary, clip: String) -> void:
	var actor := avatar.horse_visual
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	actor.animator.advance(.18)
	assert(Dispatch.dispatch(avatar, packet, true, 64) and actor.current_clip == clip)
	actor.animator.advance(.16)


func seek(actor: Node3D, phase: float) -> void:
	actor.animator.seek(actor.animator.current_animation_length * phase, true)
	actor.skeleton.force_update_all_bone_transforms()


func body_skins(actor: Node3D) -> Array[Dictionary]:
	var skins: Array[Dictionary] = []
	for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		skins.append(Ground.skin_points(mesh, actor.skeleton))
	return skins


func minimum_gap(actor: Node3D, floor: StaticBody3D, skins: Array[Dictionary]) -> float:
	var rig: Skeleton3D = actor.skeleton
	var gap := INF
	for skin: Dictionary in skins:
		gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, floor.position, floor.basis.y))
	return gap


func landmark(actor: Node3D, label: String) -> Vector3:
	var rig: Skeleton3D = actor.skeleton
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(label)).origin)


func check_giant_fall(source: Node3D, floor: StaticBody3D, body: int, row: Dictionary) -> Dictionary:
	var fallen := actor_for(body, row, source.treatment)
	fallen.global_transform = source.global_transform.rotated(Vector3.UP, .31)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	var duration: float = fallen.begin_death_from(source)
	assert(fallen.current_clip == "Death" and duration > 0.0)
	var jump := 0.0
	var labels := ["bip01 head", "cp_grasp_rhand", "cyclopsmallet" if body == 75 else "cp_grasp_lhand"]
	for label: String in labels:
		jump = maxf(jump, landmark(source, label).distance_to(landmark(fallen, label)))
	assert(jump < .002, "%d %s handoff displaced %.6f m" % [body, source.current_clip, jump])
	var gap := INF
	var skins := body_skins(fallen)
	for sample in 31:
		seek(fallen, sample / 30.0)
		gap = minf(gap, minimum_gap(fallen, floor, skins))
	assert(gap >= .0018, "%d %s fall has gap %.6f" % [body, source.current_clip, gap])
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	assert(corpse.has_node("CyclopsMallet") == (body == 75))
	corpse.free()
	fallen.free()
	return {"jump": jump, "gap": gap}
