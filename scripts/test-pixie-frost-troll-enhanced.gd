# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Fit := preload("bake-pixie-frost-troll-enhanced.gd")
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Modes := {
	128: {"0": {"5": ["PixieHoverWatch", "PixieBankedHover"], "8": ["PixieWingAlert"], "15": ["PixieLightRise"]},
		"1": {"5": ["PixieHoverWatch"]}},
	55: {"0": {"5": ["FrostTrollKnuckleLook", "FrostTrollStaggerGuard"], "8": ["FrostTrollWideAlert"],
		"11": ["FrostTrollOpenPalm", "FrostTrollOpenPalm", "FrostTrollOpenPalm"], "15": ["FrostTrollCrouchedRise"]},
		"1": {"5": ["FrostTrollKnuckleLook"]}},
}


func run() -> void:
	var installed := "--installed" in OS.get_cmdline_user_args()
	var bases := {}
	for body: int in Modes:
		bases[body] = Registry.entry(body)
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var proof := {}
	for body: int in [128, 55]:
		var base: Dictionary = bases[body]
		var row := Registry.entry(body) if installed else candidate_row(body, base)
		assert(row.enhanced_source_action_groups == Modes[body])
		Registry.entries[body] = row
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		proof[str(body)] = await review(game, body, row)
		Registry.entries[body] = base
	game.free()
	if not installed:
		var file := FileAccess.open(Fit.Destination + "terrain-receipt.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"bodies": proof, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	quit()


static func candidate_row(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.assets = {}
	for treatment: String in Installed.registered_assets(base):
		row.assets[treatment] = Fit.Destination + "%d-%s.scn" % [body, treatment]
	row.enhanced_source_action_groups = Modes[body]
	row.archive_grounded_gestures = (Fit.Pixie if body == 128 else Fit.Frost).values()
	row.presentation_script = "res://Presentation/" + (
		"SourceEnhancedPixieVisual.gd" if body == 128 else "SourceEnhancedFrostTrollVisual.gd"
	)
	return row


func review(game: Node, body: int, row: Dictionary) -> Dictionary:
	var result := {"poses": 0, "falls": 0, "routes": 0, "classic": 0, "min_gap": INF, "max_jump": 0.0,
		"clip_ranges": {}, "hashes": {}}
	var pixie := body == 128
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := visual(body, row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				var count := check_routes(avatar, game, body, Modes[body])
				result.routes += count.x
				result.classic += count.y
				result.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
			for route: String in Modes[body]["0"]:
				var seen := {}
				var clips: Array = Modes[body]["0"][route]
				for variant in clips.size():
					var clip: String = clips[variant]
					if seen.has(clip):
						continue
					seen[clip] = true
					var packet := decode(game, body, int(route), variant)
					start_fit(actor, avatar, packet, clip)
					var range := Vector2(INF, -INF)
					var minimum := INF
					for i in 31:
						move_to(actor, i / 30.0)
						var clearance := gap(actor, floor)
						assert(clearance >= .002 - .00012, "%d %s %s gap %.6f" % [body, treatment, clip, clearance])
						minimum = minf(minimum, clearance)
						var extension := wing_span(actor) if pixie else point(actor, "bip01 r hand").z
						range.x = minf(range.x, extension)
						range.y = maxf(range.y, extension)
						if not pixie:
							assert(not actor.club.visible)
						result.poses += 1
					result.min_gap = minf(result.min_gap, minimum)
					if tilt == Vector3.ZERO and treatment == "modern":
						result.clip_ranges[clip] = [range.x, range.y, minimum]
					for phase: float in [.12, .52]:
						start_fit(actor, avatar, packet, clip)
						move_to(actor, phase)
						result.max_jump = maxf(result.max_jump, check_fall(actor, row, floor))
						result.falls += 1
			if not pixie:
				actor.action_remaining = 0.0
				actor.play_gait(false, 0.0)
				actor.animator.advance(.2)
				assert(actor.club.visible, "The retained Classic stance keeps its modelled club")
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	print("PIXIE AND FROST TROLL RUNTIME ", body, " ", result)
	return result


func visual(body: int, row: Dictionary, treatment: String) -> Node3D:
	var actor: Node3D = Registry.create(body) if Installed.enabled else load(Fit.Destination + row.presentation_script.get_file()).new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func start_fit(actor: Node3D, avatar: Avatar, packet: Dictionary, clip: String) -> void:
	actor.animator.stop()
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	actor.animator.advance(.20)
	assert(Dispatch.dispatch(avatar, packet, true, 64) and actor.current_clip == clip)
	actor.animator.advance(.15)


func move_to(actor: Node3D, phase: float) -> void:
	actor.animator.seek(actor.animator.current_animation_length * phase, true)
	actor._physics_process(1.0 / 60.0)
	actor.contact.modification_processed.emit()
	actor.skeleton.force_update_all_bone_transforms()


func point(actor: Node3D, name: String) -> Vector3:
	var rig: Skeleton3D = actor.skeleton
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(name)).origin)


func wing_span(actor: Node3D) -> float:
	return point(actor, "pixie l wing3").distance_to(point(actor, "pixie r wing3"))


func gap(actor: Node3D, floor: StaticBody3D) -> float:
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	return Ground.minimum_plane_gap(actor.fitted_fall.skin, rig, rig.global_transform, floor.position, floor.basis.y)


func check_fall(actor: Node3D, row: Dictionary, floor: StaticBody3D) -> float:
	var body: int = actor.native_body
	var pixie := body == 128
	var landmarks := ["bip01 head", "pixie l wing3", "pixie r wing3"] if pixie else ["bip01 head", "bip01 r hand"]
	var dead := visual(body, row, actor.treatment)
	dead.global_transform = actor.global_transform
	dead.rotate_y(.31)
	dead.model.transform = actor.model.transform
	dead.dead = true
	dead.contact.enabled = false
	var duration: float = dead.begin_death_from(actor)
	var jump := 0.0
	for name: String in landmarks:
		jump = maxf(jump, point(actor, name).distance_to(point(dead, name)))
	assert(duration > 0.0 and jump < .002, "Body %d fall jump %.7f" % [body, jump])
	for i in 31:
		dead.animator.seek(duration * i / 30.0, true)
		assert(gap(dead, floor) >= .0019)
	var snapshot := Snapshot.capture(dead, dead.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	assert(corpse.find_child("PixieEmergence" if pixie else "FrostClub", true, false) == null)
	corpse.free()
	dead.free()
	return jump
