# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Gaps := "res://../work/creatures/native-form-audit/enhanced-source-gaps/"
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Families := {
	48: ["scorpion-bimbobushi", "Scorpion"], 242: ["scorpion-bimbobushi", "Deathwatch"],
	13: ["air-slime", "Air"], 51: ["air-slime", "Slime"],
}
const Modes := {
	48: {"0": {"5": ["ScorpionClawCheck", "ScorpionRaisedPincers"], "8": ["ScorpionClawAlert"],
		"11": ["ScorpionScissorStrike", "ScorpionScissorStrike", "ScorpionScissorStrike"],
		"14": ["ScorpionQuietBrace"], "15": ["ScorpionTailRise"]}, "1": {"5": ["ScorpionClawCheck"]}},
	242: {"0": {"2": ["DeathwatchQuietBreath", "DeathwatchTuckedWatch"],
		"5": ["DeathwatchPalpBrush", "DeathwatchAbdomenCurl"], "8": ["DeathwatchForelimbAlert"],
		"11": ["DeathwatchCrossShear", "DeathwatchCrossShear", "DeathwatchCrossShear"],
		"14": ["DeathwatchQuietBreath"], "15": ["DeathwatchQuietBreath"]}, "1": {"5": ["DeathwatchPalpBrush"]}},
	13: {"0": {"8": ["AirSpreadAlert"], "15": ["AirVortexFormation"]}, "1": {}},
	51: {"0": {"2": ["SlimeQuietPulse", "SlimeQuietPulse"], "5": ["SlimeQuietPulse", "SlimeQuietPulse"],
		"8": ["SlimeQuietPulse"], "11": ["SlimeCrestLash", "SlimeCrestLash", "SlimeCrestLash"],
		"14": ["SlimeQuietPulse"], "15": ["SlimeQuietPulse"]}, "1": {"5": ["SlimeQuietPulse"]}},
}

func run() -> void:
	var installed := "--installed" in OS.get_cmdline_user_args()
	var bases := {}
	for body: int in Families:
		bases[body] = Registry.entry(body)
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var evidence := {}
	for body: int in Families:
		var row := Registry.entry(body) if installed else candidate_row(body, bases[body])
		assert(row.enhanced_source_action_groups == Modes[body])
		Registry.entries[body] = row
		evidence[str(body)] = await review(game, body, bases[body], row, installed)
		assert(not evidence[str(body)].is_empty())
		Registry.entries[body] = bases[body]
	game.free()
	if not installed:
		var output := FileAccess.open(Gaps + "scorpion-bimbobushi/integration/terrain-receipt.json", FileAccess.WRITE)
		assert(output != null)
		output.store_string(JSON.stringify({"bodies": evidence, "script_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		output.close()
	quit()

func candidate_row(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = Modes[body]
	row.archive_grounded_gestures = [] if body == 13 else motion_packets(body).keys()
	row.assets = {}
	for treatment: String in Installed.registered_assets(base):
		row.assets[treatment] = Gaps + "%s/%d-%s.scn" % [Families[body][0], body, treatment]
	return row

func motion_packets(body: int) -> Dictionary:
	var clips := {}
	for kind: String in Modes[body]["0"]:
		var names: Array = Modes[body]["0"][kind]
		for variant in names.size():
			if not clips.has(names[variant]):
				clips[names[variant]] = [int(kind), variant]
	return clips

func review(game: Node, body: int, base: Dictionary, row: Dictionary, installed: bool) -> Dictionary:
	game.entities[body] = {"body": body, "serial": body, "hue": 0x8035}
	var clips := motion_packets(body)
	var result := {"decoded": 0, "classic": 0, "poses": 0, "terrain": {}, "hashes": {}, "interruption_recoveries": 0,
		"air_falls": 0, "falls": 0, "maximum_death_jump": 0.0, "hues": 0}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := create_fit(body, treatment, installed)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				Bake.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
				var counts := check_routes(avatar, game, body, Modes[body])
				result.decoded += counts.x
				result.classic += counts.y
				result.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				if body == 13:
					result.interruption_recoveries = check_air_interruptions(actor, avatar, game)
			for clip: String in clips:
				var selection: Array = clips[clip]
				var request := decode(game, body, selection[0], selection[1])
				var measurements := review_clip(actor, avatar, floor, request, clip)
				assert(not measurements.is_empty())
				result.poses += 31
				if tilt == Vector3.ZERO and treatment == "modern":
					result.terrain[clip] = measurements
				for phase: float in [.10, .58]:
					var fall := review_fall(actor, avatar, floor, request, phase, installed)
					assert(fall.has("jump"))
					result.air_falls += int(fall.air)
					result.falls += 1
					result.maximum_death_jump = maxf(result.maximum_death_jump, fall.jump)
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	assert(result.air_falls == 0 and result.falls == clips.size() * 10 * row.assets.size())
	for hue: int in [0, 0x8035, 0x4001 if body == 13 else 0x455]:
		var corpse := Corpses.build(body, hue)
		assert(corpse != null and corpse.get_meta("graphic_id") == 0x2006 and corpse.get_meta("corpse_body") == body)
		assert(corpse.get_meta("native_hue") == hue and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
		result.hues += 1
	print("SCORPION THROUGH SLIME ", body, ": ", result)
	return result

func create_fit(body: int, treatment: String, installed: bool) -> Node3D:
	var renderer := Gaps + "%s/SourceEnhanced%sVisual.gd" % Families[body]
	var actor: Node3D = Registry.create(body) if installed else load(renderer).new()
	actor.entry = Registry.entry(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor

func start_fit(actor: Node3D, avatar: Avatar, request: Dictionary) -> void:
	actor.animator.stop()
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	actor.animator.advance(.19)
	assert(Dispatch.dispatch(avatar, request, true, 0x40))
	actor.animator.advance(.14)

func check_air_interruptions(actor: Node3D, avatar: Avatar, game: Node) -> int:
	var rig: Skeleton3D = actor.skeleton
	var root_bone := rig.find_bone("root")
	assert(root_bone >= 0)
	for route: String in ["alert", "classic", "walk"]:
		start_fit(actor, avatar, decode(game, 13, 15, 0))
		actor.animator.seek(actor.animator.current_animation_length * .12, true)
		assert(rig.get_bone_pose_scale(root_bone).y < .35)
		match route:
			"alert":
				assert(Dispatch.dispatch(avatar, decode(game, 13, 8, 0), true, 64))
			"classic":
				assert(Classic.dispatch(avatar, {"protocol": "classic", "body": 13, "serial": 13,
					"action": 4, "frames": 5, "repeat_count": 1, "delay": 0}))
			_:
				actor.action_remaining = 0.0
				actor.play_gait(true, 1.5)
		for step in 21:
			actor.animator.advance(1.0 / 60.0)
		assert(rig.get_bone_pose_scale(root_bone).is_equal_approx(Vector3.ONE), route)
	return 3

func move_to(actor: Node3D, phase: float) -> void:
	actor.animator.seek(actor.animator.current_animation_length * phase, true)
	actor._physics_process(1.0 / 60.0)
	actor.contact.modification_processed.emit()
	actor.skeleton.force_update_all_bone_transforms()

static func bone(actor: Node3D, label: String) -> Vector3:
	var rig: Skeleton3D = actor.skeleton
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(label)).origin)

func review_clip(actor: Node3D, avatar: Avatar, floor: StaticBody3D, request: Dictionary, clip: String) -> Dictionary:
	start_fit(actor, avatar, request)
	assert(actor.current_clip == clip)
	var skin: Dictionary
	match actor.native_body:
		13: skin = actor.body_skin
		51: skin = actor.support_skin
		_: skin = actor.gesture_ground.skin
	var lowest := INF
	var highest := -INF
	var gap := INF
	for i in 31:
		move_to(actor, i / 30.0)
		gap = minf(gap, Ground.minimum_plane_gap(skin, actor.skeleton, actor.skeleton.global_transform,
			floor.position, floor.basis.y))
		var label: String = {13: "Head", 51: "bip01 head", 48: "bip01 tail4", 242: "bip01 tail1"}[actor.native_body]
		var motion := (bone(actor, label) - floor.position).dot(floor.basis.y)
		if clip in ["ScorpionScissorStrike", "DeathwatchCrossShear"]:
			motion = bone(actor, "bip01 l hand").distance_to(bone(actor, "bip01 r hand"))
		elif clip in ["ScorpionRaisedPincers", "DeathwatchForelimbAlert"]:
			motion = ((bone(actor, "bip01 l hand") + bone(actor, "bip01 r hand")) * .5 - floor.position).dot(floor.basis.y)
		lowest = minf(lowest, motion)
		highest = maxf(highest, motion)
	assert(gap >= .0019, "%s slope %s gap %f" % [clip, floor.rotation, gap])
	return {"gap": gap, "minimum": lowest, "maximum": highest}

func review_fall(actor: Node3D, avatar: Avatar, floor: StaticBody3D, request: Dictionary,
		phase: float, installed: bool) -> Dictionary:
	start_fit(actor, avatar, request)
	move_to(actor, phase)
	var label := "Head" if actor.native_body == 13 else "bip01 head" if actor.native_body == 51 else "bip01 neck"
	var prior := bone(actor, label)
	var fall := create_fit(actor.native_body, actor.treatment, installed)
	fall.global_transform = actor.global_transform
	fall.model.transform = actor.model.transform
	fall.dead = true
	fall.contact.enabled = false
	var duration: float = fall.begin_death_from(actor)
	var jump := prior.distance_to(bone(fall, label))
	assert(duration > 0.0 and jump < .002, "%s %.2f %s %f" % [actor.current_clip, phase, floor.rotation, jump])
	for i in 31:
		fall.animator.seek(duration * i / 30.0, true)
		assert(Ground.minimum_plane_gap(fall.fitted_fall.skin, fall.skeleton, fall.skeleton.global_transform,
			floor.position, floor.basis.y) >= .0019)
	var snapshot := Snapshot.capture(fall, fall.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "MultiMeshInstance3D", true, false).is_empty())
	var airborne: bool = fall.current_clip == "AirDeath"
	corpse.free()
	fall.free()
	return {"air": airborne, "jump": jump}
