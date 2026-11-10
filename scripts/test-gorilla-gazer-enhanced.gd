# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/gorilla-gazer/"
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Modes := {
	29: {"0": {"2": ["GorillaForearmGuard", "GorillaForearmGuard"],
		"5": ["GorillaLowWatch", "GorillaChestBeat"], "8": ["GorillaArmsWarning"],
		"11": ["GorillaOverheadDrop", "GorillaOverheadDrop", "GorillaOverheadDrop"],
		"14": ["GorillaLowBreath"], "15": ["GorillaLowBreath"]}, "1": {"5": ["GorillaLowWatch"]}},
	22: {"0": {"2": ["GazerTiltRecoil", "GazerTiltRecoil"], "5": ["GazerHoverScan", "GazerOrbitFeint"],
		"8": ["GazerRaisedEyeAlert"], "11": ["GazerEyeFan", "GazerEyeFan", "GazerEyeFan"],
		"14": ["GazerTentacleSurvey"], "15": ["GazerUnfurl"]}, "1": {"5": ["GazerHoverScan"]}},
}
const Trials := {29: "SourceEnhancedGorillaVisual.gd", 22: "SourceEnhancedGazerVisual.gd"}
var using_installed := false

func run() -> void:
	var bases := {29: Registry.entry(29), 22: Registry.entry(22)}
	using_installed = "--installed" in OS.get_cmdline_user_args()
	if using_installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var bodies := {}
	for body: int in Modes:
		bodies[str(body)] = await review(game, body, bases[body])
		assert(not bodies[str(body)].is_empty())
	game.free()
	if not using_installed:
		var file := FileAccess.open(Stage + "terrain-receipt.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"bodies": bodies, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	quit()

func review(game: Node, body: int, base: Dictionary) -> Dictionary:
	var row := Registry.entry(body) if using_installed else base.duplicate(true)
	var poses := {}
	var groups: Dictionary = Modes[body]["0"]
	for type: String in groups:
		for variation in groups[type].size():
			if not poses.has(groups[type][variation]):
				poses[groups[type][variation]] = [int(type), variation]
	if not using_installed:
		row.enhanced_source_action_groups = Modes[body]
		row.archive_grounded_gestures = poses.keys() if body == 29 else []
		row.presentation_script = "res://Presentation/TrialGorillaVisual.gd" if body == 29 else "res://Presentation/TrialGazerVisual.gd"
		row.assets = {}
		for treatment: String in base.asset_sha256:
			row.assets[treatment] = Stage + "%d-%s.scn" % [body, treatment]
		Registry.entries[body] = row
	game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
	var result := {"selections": 0, "classic": 0, "poses": 0, "hashes": {}, "clips": {}, "falls": [], "hues": 0, "eye_flashes": 0}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := create_fit(body, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				Bake.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
				var counts := check_routes(avatar, game, body, Modes[body])
				result.selections += counts.x
				result.classic += counts.y
				result.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				if body == 22:
					result.eye_flashes += check_eye_flashes(avatar, game, body)
			for clip: String in poses:
				var choice: Array = poses[clip]
				var packet := decode(game, body, choice[0], choice[1])
				var report := sample_fit(avatar, floor, packet, clip, body)
				assert(not report.is_empty())
				if tilt == Vector3.ZERO and treatment == "modern":
					result.clips[clip] = report
				result.poses += 31
			for type: int in ([5, 11] if body == 29 else [11, 15]):
				var packet := decode(game, body, type, 1 if body == 29 and type == 5 else 0)
				for phase: float in [.28, .54]:
					result.falls.append(check_fall(avatar, floor, packet, treatment, phase))
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	for hue: int in [0, 0x8035, 0x455]:
		var corpse := Corpses.build(body, hue)
		assert(corpse != null and corpse.get_meta("graphic_id") == 0x2006 and corpse.get_meta("corpse_body") == body)
		assert(corpse.get_meta("native_hue") == hue and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
		result.hues += 1
	Registry.entries[body] = base
	assert(result.selections == 144 and result.classic == 108 and result.poses == poses.size() * 465)
	assert(result.falls.size() == 60 and result.falls.all(func(row: Dictionary): return row.has("jump")))
	assert(result.eye_flashes >= 3 if body == 22 else result.eye_flashes == 0)
	print("GORILLA/GAZER ", body, ": ", result.poses, " terrain poses, ", result.falls.size(), " falls, ", result.clips)
	return result

func create_fit(body: int, treatment: String) -> Node3D:
	var actor: Node3D = Registry.create(body) if using_installed else load(Stage + Trials[body]).new()
	actor.entry = Registry.entry(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor

func start_motion(avatar: Avatar, packet: Dictionary) -> void:
	var actor := avatar.horse_visual
	actor.animator.stop()
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	actor.animator.advance(.19)
	assert(Dispatch.dispatch(avatar, packet, true, 64))
	actor.animator.advance(.13)
	actor.animator.seek(0.0, true)

func sample_fit(avatar: Avatar, floor: StaticBody3D, packet: Dictionary, clip: String, body: int) -> Dictionary:
	var actor := avatar.horse_visual
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var skin := Ground.skin_points(actor.model.find_child("Body", true, false), rig)
	start_motion(avatar, packet)
	assert(actor.current_clip == clip)
	var result := {"gap": INF, "first": 0.0, "lowest": INF, "highest": -INF, "last": 0.0}
	var head := rig.find_bone("bip01 head")
	var eye := rig.find_bone("gazers_gazer_eyebone1")
	for i in 31:
		player.seek(player.current_animation_length * i / 30.0, true)
		actor._physics_process(1.0 / 60.0)
		rig.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, floor.position, floor.basis.y)
		var head_at := rig.to_global(rig.get_bone_global_pose(head).origin)
		var value := (head_at - floor.position).dot(floor.basis.y) if body == 29 else (
			head_at.distance_to(rig.to_global(rig.get_bone_global_pose(eye).origin)))
		result.gap = minf(result.gap, gap)
		result.lowest = minf(result.lowest, value)
		result.highest = maxf(result.highest, value)
		if i == 0:
			result.first = value
		if i == 30:
			result.last = value
	assert(result.gap >= .0019, "%s on %s: %s" % [clip, floor.rotation, result])
	if clip == "GazerUnfurl":
		assert(result.last > result.first + .40, str(result))
	if clip in ["GorillaChestBeat", "GorillaOverheadDrop"]:
		assert(result.highest > result.first + .20, str(result))
	return result

func check_eye_flashes(avatar: Avatar, game: Node, body: int) -> int:
	var actor := avatar.horse_visual
	assert(Classic.dispatch(avatar, {"protocol": "classic", "action": 6, "body": body, "serial": body,
		"frames": 5, "repeat_count": 1, "delay": 0}) and actor.current_clip == "EyeVolley")
	actor.animator.advance(.13)
	actor.animator.seek(actor.animator.current_animation_length * .55, true)
	var visible := 0
	for index in actor.sparks.size():
		var spark: MeshInstance3D = actor.sparks[index]
		if spark.visible:
			var eye: int = actor.skeleton.find_bone("gazers_gazer_eyebone%d" % (index + 1))
			assert(spark.global_position.is_equal_approx(actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(eye).origin)))
			visible += 1
	assert(visible > 0)
	start_motion(avatar, decode(game, body, 15, 0))
	assert(actor.sparks.all(func(spark: MeshInstance3D): return not spark.visible))
	return visible

func check_fall(avatar: Avatar, floor: StaticBody3D, packet: Dictionary, treatment: String, phase: float) -> Dictionary:
	var source := avatar.horse_visual
	var body := int(source.native_body)
	start_motion(avatar, packet)
	source.animator.seek(source.animator.current_animation_length * phase, true)
	source._physics_process(1.0 / 60.0)
	source.skeleton.force_update_all_bone_transforms()
	var head := source.skeleton.find_bone("bip01 head") as int
	var previous: Vector3 = source.skeleton.to_global(source.skeleton.get_bone_global_pose(head).origin)
	var fallen := create_fit(body, treatment)
	fallen.global_transform = source.global_transform
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	var duration: float = fallen.begin_death_from(source)
	assert(duration > 0.0 and fallen.current_clip == "Death")
	var rig: Skeleton3D = fallen.skeleton
	rig.force_update_all_bone_transforms()
	var jump := previous.distance_to(rig.to_global(rig.get_bone_global_pose(head).origin))
	assert(jump < .002, "%d %s %.2f jumps %f metres" % [body, source.current_clip, phase, jump])
	var skin := Ground.skin_points(fallen.model.find_child("Body", true, false), rig)
	var gap := INF
	for i in 31:
		fallen.animator.seek(duration * i / 30.0, true)
		rig.force_update_all_bone_transforms()
		gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, floor.position, floor.basis.y))
	assert(gap >= .0019)
	var frozen := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not frozen.is_empty() and frozen.body == body)
	var corpse: Node3D = frozen.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	corpse.free()
	fallen.free()
	return {"jump": jump, "gap": gap, "phase": phase}
