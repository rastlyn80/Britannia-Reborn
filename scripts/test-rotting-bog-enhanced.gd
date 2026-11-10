# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Rotting := preload("bake-rotting-corpse-enhanced.gd")
const Bog := preload("bake-bog-thing-enhanced.gd")
const Renderers := {155: "SourceEnhancedRottingCorpseVisual.gd", 780: "SourceEnhancedBogThingVisual.gd"}


static func modes_for(body: int) -> Dictionary:
	var clips: Dictionary = Rotting.Clips if body == 155 else Bog.Clips
	var combat := {"5": [clips[26], clips[27]], "8": [clips[28]], "15": [clips[23]]}
	if body == 155:
		combat["2"] = [clips[15], clips[15]]
		combat["14"] = [clips[11]]
	else:
		combat["11"] = [clips[4], clips[4], clips[4]]
		combat["14"] = [clips[25]]
	return {"0": combat, "1": {"5": [clips[26]]}}


static func row_for(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = modes_for(body)
	row.archive_grounded_gestures = (Rotting.Clips if body == 155 else Bog.Clips).values()
	for treatment: String in row.assets:
		row.assets[treatment] = Rotting.Destination + "%d-%s.scn" % [body, treatment]
	return row


func run() -> void:
	var installed := "--installed" in OS.get_cmdline_user_args()
	var bases := {}
	for body: int in Renderers:
		bases[body] = Registry.entry(body)
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var bodies := {}
	for body: int in Renderers:
		var row := Registry.entry(body) if installed else row_for(body, bases[body])
		assert(row.enhanced_source_action_groups == modes_for(body))
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		bodies[str(body)] = await review(game, body, bases[body], row)
		var expected_clips: int = (Rotting.Clips if body == 155 else Bog.Clips).size()
		assert(bodies[str(body)].poses == expected_clips * 3 * Slopes.size() * 31)
		assert(bodies[str(body)].falls == expected_clips * 3 * Slopes.size() * 2)
	game.free()
	if not installed:
		var file := FileAccess.open(Rotting.Destination + "terrain-receipt.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"bodies": bodies, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	quit()


func actor_for(body: int, row: Dictionary, treatment: String) -> Node3D:
	var actor: Node3D
	if Installed.enabled:
		actor = Registry.create(body)
	else:
		var renderer := load(Rotting.Destination + Renderers[body]) as GDScript
		actor = renderer.new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func review(game: Node, body: int, base: Dictionary, row: Dictionary) -> Dictionary:
	var report := {"poses": 0, "falls": 0, "gap": INF, "fall_gap": INF, "jump": 0.0, "routes": 0,
		"classic": 0, "hashes": {}, "growth_recoveries": 0, "prop_poses": 0, "classic_continuations": 0}
	var bog := body == 780
	var modes := modes_for(body)
	var packets := {}
	for kind: String in modes["0"]:
		var clips: Array = modes["0"][kind]
		for variation in clips.size():
			packets[clips[variation]] = decode(game, body, int(kind), variation)
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := actor_for(body, row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			var skins := body_skins(actor)
			if tilt == Vector3.ZERO:
				var baked := (load(row.assets[treatment]) as PackedScene).instantiate()
				var baked_player := baked.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
				Rotting.verify_base_clips(baked_player, Registry.asset_path(base, treatment))
				baked.free()
				report.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				var counts := check_routes(avatar, game, body, modes)
				report.routes += counts.x
				report.classic += counts.y
			for clip: String in packets:
				start_fit(avatar, packets[clip], clip)
				for sample in 31:
					var phase := sample / 30.0
					seek(actor, phase)
					plant(actor, bog)
					var gap := minimum_gap(actor, floor, skins)
					assert(gap >= -.0008, "%d %s %.2f support gap %.6f" % [body, clip, phase, gap])
					report.gap = minf(report.gap, gap)
					report.poses += 1
					if bog:
						check_footprint(actor, floor)
						var reach := smoothstep(.29, .47, phase) * (1.0 - smoothstep(.68, .89, phase))
						assert(actor.tongue.visible == (clip == Bog.Clips[26] and reach > .025))
						report.prop_poses += 1
				for phase: float in [.18, .65]:
					start_fit(avatar, packets[clip], clip)
					seek(actor, phase)
					plant(actor, bog)
					var result := check_fit_fall(actor, floor, body, row)
					report.jump = maxf(report.jump, result.jump)
					report.fall_gap = minf(report.fall_gap, result.gap)
					report.falls += 1
			if bog:
				start_fit(avatar, packets[Bog.Clips[23]], Bog.Clips[23])
				seek(actor, .21)
				var root_joint: int = actor.skeleton.find_bone("__root")
				assert(actor.skeleton.get_bone_pose_scale(root_joint).x < .35)
				assert(Dispatch.dispatch(avatar, {"protocol": "classic", "action": 4, "body": body}, true, 64))
				actor.animator.advance(.26)
				assert(actor.skeleton.get_bone_pose_scale(root_joint).distance_to(Vector3.ONE) < .0001)
				assert(not actor.tongue.visible)
				report.growth_recoveries += 1
				for group: int in [2, 3]:
					check_bog_classic_fall(row, treatment, group)
					report.classic_continuations += 1
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	print("ROTTING CORPSE AND BOG THING RUNTIME ", body, " ", report)
	return report


func check_bog_classic_fall(row: Dictionary, treatment: String, group: int) -> void:
	var source := actor_for(780, row, treatment)
	plant(source, true)
	assert(source.receive_action({"protocol": "classic", "body": 780, "action": group}))
	source.animator.advance(.15)
	seek(source, .48)
	var time: float = source.animator.current_animation_position
	var speed: float = source.animator.get_playing_speed()
	var fallen := actor_for(780, row, treatment)
	fallen.global_transform = source.global_transform
	fallen.model.transform = source.model.transform
	fallen.dead = true
	var duration: float = fallen.begin_death_from(source)
	assert(fallen.current_clip == "Death" and is_equal_approx(fallen.animator.current_animation_position, time))
	assert(is_equal_approx(fallen.animator.get_playing_speed(), speed))
	assert(is_equal_approx(duration, (source.animator.current_animation_length - time) / speed))
	for joint: String in ["body", "r finger 02 b", "tail 02"]:
		assert(landmark(source, joint).distance_to(landmark(fallen, joint)) < .001)
	fallen.free()
	source.free()


func start_fit(avatar: Avatar, packet: Dictionary, clip: String) -> void:
	var actor := avatar.horse_visual
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	actor.animator.advance(.24)
	assert(Dispatch.dispatch(avatar, packet, true, 64) and actor.current_clip == clip)
	actor.animator.advance(.16)


func check_fit_fall(source: Node3D, floor: StaticBody3D, body: int, row: Dictionary) -> Dictionary:
	var fallen := actor_for(body, row, source.treatment)
	fallen.global_transform = source.global_transform.rotated(Vector3.UP, -.27)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	var duration: float = fallen.begin_death_from(source)
	assert(duration > 0.0 and fallen.current_clip == "Death")
	var jump := 0.0
	var joints := ["bip01 head", "bip01 l foot", "bip01 r hand"] if body == 155 else [
		"body", "r finger 02 b", "tail 02"]
	for joint: String in joints:
		jump = maxf(jump, landmark(source, joint).distance_to(landmark(fallen, joint)))
	assert(jump < .002, "%d %s handoff displaced %.6f m" % [body, source.current_clip, jump])
	var gap := INF
	var skins := body_skins(fallen)
	for sample in 31:
		if sample > 0:
			fallen.animator.advance(duration / 30.0)
		fallen.skeleton.force_update_all_bone_transforms()
		gap = minf(gap, minimum_gap(fallen, floor, skins))
	assert(gap >= -.0008, "%d %s fall has gap %.6f" % [body, source.current_clip, gap])
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	assert(corpse.find_child("BogThingTongue", true, false) == null)
	corpse.free()
	fallen.free()
	return {"jump": jump, "gap": gap}


func plant(actor: Node3D, bog: bool) -> void:
	actor._physics_process(1.0 / 60.0)
	if not bog:
		actor.contact._process_modification_with_delta(1.0 / 60.0)
		actor.contact.modification_processed.emit()
	actor.skeleton.force_update_all_bone_transforms()


func check_footprint(actor: Node3D, floor: StaticBody3D) -> void:
	var matrices: Array[Transform3D] = actor.skin_transforms(actor.base_mesh, actor.skeleton.global_transform)
	var arrays: Array = actor.base_mesh.mesh.surface_get_arrays(0)
	var gap := INF
	assert(actor.footprint.size() == 103)
	for vertex: int in actor.footprint:
		var point: Vector3 = actor.weighted_point(arrays, matrices, vertex)
		gap = minf(gap, (point - floor.position).dot(floor.basis.y))
	assert(absf(gap) < .0008, "Bog Thing footprint moved %.6f m from the plane" % gap)
