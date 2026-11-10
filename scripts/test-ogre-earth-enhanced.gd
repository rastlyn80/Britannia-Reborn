# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/ogre-earth/"
const FitOgre := preload("res://Presentation/SourceEnhancedFieldVisual.gd")
const Formation := "EarthStoneFormation"
const StoneFall := "EarthStoneFall"
var fitted_installed := false
const SkinGeometry := preload("res://Presentation/SkinGeometry.gd")
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Modes := {
	1: {"0": {"5": ["OgreLookDown", "OgreBrowGuard"], "8": ["OgreReadyLean"],
		"11": ["OgreTurningSweep", "OgreTurningSweep", "OgreTurningSweep"], "15": ["OgreCrouchRise"]},
		"1": {"5": ["OgreLookDown"]}},
	14: {"0": {"5": ["EarthFistCheck", "EarthHeavyGuard"], "8": ["EarthLowBrace"],
		"11": ["EarthTwoHandSlam", "EarthTwoHandSlam", "EarthTwoHandSlam"], "15": ["EarthStoneFormation"]},
		"1": {"5": ["EarthFistCheck"]}},
}

func run() -> void:
	var bases := {1: Registry.entry(1), 14: Registry.entry(14)}
	fitted_installed = "--installed" in OS.get_cmdline_user_args()
	if fitted_installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var results := {}
	for body: int in Modes:
		results[str(body)] = await review_candidate(game, body, bases[body])
		assert(not results[str(body)].is_empty())
	game.free()
	if not fitted_installed:
		var file := FileAccess.open(Stage + "terrain-candidate.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"bodies": results, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	quit()

func review_candidate(game: Node, body: int, base: Dictionary) -> Dictionary:
	var row := Registry.entry(body) if fitted_installed else base.duplicate(true)
	var slots := {"5:0": [5, 0], "5:1": [5, 1], "8": [8, 0], "11": [11, 0], "15": [15, 0]}
	var clips := {}
	for packet: Array in slots.values():
		clips[Modes[body]["0"][str(packet[0])][packet[1]]] = packet
	if not fitted_installed:
		row.enhanced_source_action_groups = Modes[body]
		row.archive_grounded_gestures = clips.keys().filter(func(clip: String): return clip != Formation)
		for treatment: String in row.assets:
			row.assets[treatment] = Stage + ("14-formation-%s.scn" % treatment if body == 14 else "1-%s.scn" % treatment)
		Registry.entries[body] = row
	game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
	var result := {"selections": 0, "classic": 0, "poses": 0, "clips": {}, "joins": [], "falls": [], "hashes": {}}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := create_actor(body, row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				Bake.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
				result.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				var routes := check_routes(avatar, game, body, Modes[body])
				result.selections += routes.x
				result.classic += routes.y
			for name: String in clips:
				var packet: Array = clips[name]
				var pose := sample_candidate(avatar, floor, decode(game, body, packet[0], packet[1]), name)
				assert(pose.gap >= -.003, "%s %s: %s" % [name, floor.rotation, pose])
				result.poses += 31
				if tilt == Vector3.ZERO and treatment == "modern":
					result.clips[name] = pose
				if name == Formation:
					result.joins.append(pose.join)
					assert(pose.first_pieces == 1 and pose.maximum_pieces == 15 and pose.join < .003, str(pose))
					for phase: float in [.035, .26, .57]:
						result.falls.append(check_formation_fall(avatar, floor, decode(game, body, 15, 0), row, treatment, phase))
					assert(Dispatch.dispatch(avatar, decode(game, body, 5, 0), true, 64))
					actor.animator.advance(.13)
					assert(actor.living_mesh.visible and not actor.pieces.visible)
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	Registry.entries[body] = base
	assert(result.selections == 96 and result.classic == 72 and result.poses == 2325)
	assert(result.falls.size() == (45 if body == 14 else 0) and result.falls.all(func(fall: Dictionary): return fall.has("jump")))
	print("OGRE/EARTH CANDIDATE ", body, ": ", result.poses, " motion poses, ", result.falls.size(), " stone falls, ", result.clips)
	return result

func sample_candidate(avatar: Avatar, floor: StaticBody3D, request: Dictionary, clip: String) -> Dictionary:
	var actor := avatar.horse_visual
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var forming := clip == Formation
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	assert(Dispatch.dispatch(avatar, request, true, 0x40) and actor.current_clip == clip)
	player.advance(.13)
	var low := INF
	var wrist_low := INF
	var wrist_high := -INF
	var neck_low := INF
	var neck_high := -INF
	var first_pieces := 0
	var maximum_pieces := 0
	var join := 0.0
	for i in 31:
		if forming and i == 18:
			player.seek(player.current_animation_length * .5999, true)
			assert(actor.pieces.visible)
			var before: AABB = piece_extent(actor, floor).bounds
			player.seek(player.current_animation_length * .6001, true)
			assert(actor.living_mesh.visible and not actor.pieces.visible)
			var after := SkinGeometry.deformed_bounds(mesh, rig)
			join = maxf(before.position.distance_to(after.position), before.end.distance_to(after.end))
		player.seek(player.current_animation_length * i / 30.0, true)
		for step in 12:
			actor._physics_process(1.0 / 60.0)
		if actor.contact.enabled:
			actor.contact._process_modification_with_delta(1.0 / 60.0)
			actor.contact.modification_processed.emit()
		rig.force_update_all_bone_transforms()
		if forming and actor.pieces.visible:
			var points := piece_extent(actor, floor)
			low = minf(low, points.gap)
			if i == 0:
				first_pieces = points.count
			maximum_pieces = maxi(maximum_pieces, points.count)
		else:
			low = minf(low, Ground.minimum_plane_gap(skin, rig, rig.global_transform, floor.position, floor.basis.y))
		var wrist := rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 r hand")).origin).y
		var neck := rig.to_global(rig.get_bone_global_pose(rig.find_bone("bip01 neck")).origin).y
		wrist_low = minf(wrist_low, wrist)
		wrist_high = maxf(wrist_high, wrist)
		neck_low = minf(neck_low, neck)
		neck_high = maxf(neck_high, neck)
	return {"gap": low, "wrist_range": wrist_high - wrist_low, "neck_range": neck_high - neck_low,
		"first_pieces": first_pieces, "maximum_pieces": maximum_pieces, "join": join}

func piece_extent(actor: Node3D, floor: StaticBody3D) -> Dictionary:
	var low := INF
	var count := 0
	var bounds := AABB()
	for piece: MeshInstance3D in actor.piece_points:
		if not piece.visible:
			continue
		for vertex: Vector3 in actor.piece_points[piece]:
			var point := piece.to_global(vertex)
			if is_inf(low):
				bounds = AABB(point, Vector3.ZERO)
			bounds = bounds.expand(point)
			low = minf(low, floor.basis.y.dot(point - floor.position))
		count += 1
	return {"gap": low, "count": count, "bounds": bounds}

func check_formation_fall(avatar: Avatar, floor: StaticBody3D, request: Dictionary, row: Dictionary,
		treatment: String, phase: float) -> Dictionary:
	var source := avatar.horse_visual
	source.animator.stop()
	assert(Dispatch.dispatch(avatar, request, true, 64))
	source.animator.advance(.13)
	source.animator.seek(0.0, true)
	source.animator.seek(source.animator.current_animation_length * phase, true)
	assert(source.pieces.visible and not source.living_mesh.visible, "Formation phase %f must show only stones" % phase)
	var before := piece_extent(source, floor)
	var fallen := create_actor(14, row, treatment)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	assert(is_equal_approx(fallen.begin_death_from(source), .48))
	assert(fallen.current_clip == StoneFall and fallen.falling_pieces.size() == before.count)
	var after: AABB = piece_extent(fallen, floor).bounds
	var bounds: AABB = before.bounds
	var jump := maxf(bounds.position.distance_to(after.position), bounds.end.distance_to(after.end))
	assert(jump < .002, "Falling stones first-frame jump %f" % jump)
	var minimum := INF
	for i in 31:
		fallen.advance_stone_fall(float(i) / 30.0)
		var extent := piece_extent(fallen, floor)
		minimum = minf(minimum, extent.gap)
		assert(extent.count == before.count)
	assert(minimum >= .0019)
	var frozen := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not frozen.is_empty() and frozen.body == 14)
	var corpse: Node3D = frozen.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.get_meta("death_clip") == StoneFall)
	assert(corpse.get_child_count() == before.count and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	corpse.free()
	fallen.free()
	return {"phase": phase, "jump": jump, "minimum_gap": minimum, "pieces": before.count}


func create_actor(body: int, row: Dictionary, treatment: String) -> Node3D:
	var actor: Node3D
	if fitted_installed:
		actor = Registry.create(body)
	else:
		actor = load(Stage + "SourceEnhancedEarthVisual.gd").new() if body == 14 else FitOgre.new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor
