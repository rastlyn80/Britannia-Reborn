# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Cat := preload("res://../scripts/bake-cat-enhanced.gd")
const CatVisual := preload("res://Presentation/CatActionsVisual.gd")
const CatModes := {"0": {
	"2": ["CatTailRecoil", "CatTailRecoil"], "5": ["CatListening", "CatRearAndSwipe"], "8": ["CatStartle"],
	"11": ["CatSpring", "CatSpring", "CatSpring"], "14": ["CatQuietStand"], "15": ["CatQuietStand"],
}, "1": {"5": ["CatListening"]}}
const ClipPackets := [[4, 11, 0], [15, 2, 0], [25, 14, 0], [26, 5, 0], [27, 5, 1], [28, 8, 0]]

func run() -> void:
	var base := Registry.entry(201)
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	var row := Registry.entry(201) if installed else base.duplicate(true)
	if not installed:
		row.assets.modern = Cat.CatOutput
		row.enhanced_source_action_groups = CatModes
		row.archive_grounded_gestures = Cat.CatClips.values()
		Registry.entries[201] = row
	assert(row.enhanced_source_action_groups == CatModes)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[201] = {"serial": 201, "body": 201, "hue": 0x8035}
	var actor: Node3D = Registry.create(201) if installed else CatVisual.new()
	actor.entry = row
	root.add_child(actor)
	actor.apply_identity(201, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	var initial_model: Transform3D = actor.model.transform
	var avatar := Avatar.new()
	avatar.horse_visual = actor
	Bake.verify_base_clips(actor.animator, Registry.asset_path(base, "modern"))
	var counts := check_routes(avatar, game, 201, CatModes)
	var sampled := 0
	var gaps := {}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for entry: Array in ClipPackets:
			var clip: String = Cat.CatClips[entry[0]]
			var gap := sample(avatar, floor, decode(game, 201, entry[1], entry[2]), clip)
			assert(gap >= .0018, "%s at %s: %f" % [clip, tilt, gap])
			gaps[clip] = minf(gap, gaps.get(clip, INF))
			sampled += 31
		floor.free()
		await physics_frame
	actor.gesture_ground.release(actor)
	actor.model.transform = initial_model
	var flight := measure_spring(actor)
	var rear := measure_rear(actor)
	print("CAT SPRING AND SWIPE GEOMETRY: ", flight, " ", rear)
	assert(counts == Vector2i(48, 36) and sampled == 930)
	assert(.23 < flight.peak and flight.peak < .30 and absf(flight.start) < .004 and absf(flight.end) < .004)
	assert(flight.forward > .09 and flight.forward < .15 and flight.return_error < .002)
	assert(rear.paw_lift > .10 and rear.hind_drift < .015)
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(201, hue)
		assert(corpse != null and corpse.get_meta("graphic_id") == 0x2006 and corpse.get_meta("static_cadaver"))
		assert(corpse.get_meta("corpse_body") == 201 and corpse.get_meta("native_hue") == hue)
		corpse.free()
	var evidence := {"routes": counts.x, "classic_comparisons": counts.y, "terrain_poses": sampled, "corpse_hues": 3,
		"gaps": gaps, "flight": flight, "rear": rear, "scene_sha256": FileAccess.get_sha256(row.assets.modern),
		"test_sha256": FileAccess.get_sha256(get_script().resource_path)}
	print("CAT ENHANCED CHECKS: ", evidence)
	if not installed:
		var report := FileAccess.open(Cat.CatOutput.get_base_dir().path_join("cat-enhanced-candidate.json"), FileAccess.WRITE)
		assert(report != null)
		report.store_string(JSON.stringify(evidence, "\t"))
		report.close()
	avatar.free()
	actor.free()
	game.free()
	quit()

func measure_spring(actor: Node3D) -> Dictionary:
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	var skin := Ground.skin_points(actor.model.find_children("*", "MeshInstance3D", true, false)[0], rig)
	player.play("CatSpring", 0.0)
	player.advance(0.0)
	var center := Cat.new()
	var start := center.joint_world(rig, "bip01")
	var forward := (center.joint_world(rig, "bip01 head") - center.hind_midpoint(rig)).slide(Vector3.UP).normalized()
	var result := {"peak": 0.0, "forward": 0.0}
	for i in 81:
		player.seek(player.current_animation_length * i / 80.0, true)
		rig.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var travel := (center.joint_world(rig, "bip01") - start).dot(forward)
		result.peak = maxf(result.peak, gap)
		result.forward = maxf(result.forward, travel)
		if i == 0:
			result["start"] = gap
		elif i == 80:
			result["end"] = gap
			result["return_error"] = center.joint_world(rig, "bip01").distance_to(start)
	center.free()
	return result

func measure_rear(actor: Node3D) -> Dictionary:
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	var pose := Cat.new()
	player.play("CatRearAndSwipe", 0.0)
	player.advance(0.0)
	var start := pose.hind_midpoint(rig)
	var paw := pose.joint_world(rig, "bip01 r hand").y
	var result := {"paw_lift": 0.0, "hind_drift": 0.0}
	for i in 81:
		player.seek(player.current_animation_length * i / 80.0, true)
		rig.force_update_all_bone_transforms()
		result.paw_lift = maxf(result.paw_lift, pose.joint_world(rig, "bip01 r hand").y - paw)
		result.hind_drift = maxf(result.hind_drift, (pose.hind_midpoint(rig) - start).slide(Vector3.UP).length())
	pose.free()
	return result
