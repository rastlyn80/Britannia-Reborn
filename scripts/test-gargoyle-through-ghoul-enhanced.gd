# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Gaps := "res://../work/creatures/native-form-audit/enhanced-source-gaps/"
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Families := {
	4: ["gargoyle-headless", "Gargoyle"], 31: ["gargoyle-headless", "Headless"],
	74: ["imp-ghoul", "Imp"], 153: ["imp-ghoul", "Ghoul"],
}
const Modes := {
	4: {"0": {"5": ["GargoyleWingWatch", "GargoyleWingFeint"], "8": ["GargoyleWingAlert"],
		"15": ["GargoyleWingRise"]}, "1": {"5": ["GargoyleWingWatch"]}},
	31: {"0": {"8": ["HeadlessCrookedAlert"], "15": ["HeadlessGatherRise"]}, "1": {}},
	74: {"0": {"5": ["ImpQuietHover", "ImpGlideFeint"], "8": ["ImpWingAlert"],
		"11": ["ImpWingFlick", "ImpWingFlick", "ImpWingFlick"], "15": ["ImpUnfurl"]}, "1": {"5": ["ImpQuietHover"]}},
	153: {"0": {"8": ["GhoulCrookedReach"], "15": ["GhoulKneelingRise"]}, "1": {}},
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
		var output := FileAccess.open(Gaps + "gargoyle-headless/integration/terrain-receipt.json", FileAccess.WRITE)
		assert(output != null)
		output.store_string(JSON.stringify({"bodies": evidence, "script_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		output.close()
	quit()

func candidate_row(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = Modes[body]
	row.archive_grounded_gestures = motion_packets(body).keys()
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
	var result := {"decoded": 0, "classic": 0, "poses": 0, "terrain": {}, "hashes": {},
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
				result.decoded += counts.x + (check_flight(avatar, game) if body == 4 else 0)
				result.classic += counts.y
				result.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
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
	assert(result.air_falls == (15 if body == 4 else 0) and result.falls == clips.size() * 30)
	for hue: int in [0, 0x8035, 0x455]:
		var corpse := Corpses.build(body, hue)
		assert(corpse != null and corpse.get_meta("graphic_id") == 0x2006 and corpse.get_meta("corpse_body") == body)
		assert(corpse.get_meta("native_hue") == hue and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
		result.hues += 1
	print("GARGOYLE THROUGH GHOUL ", body, ": ", result)
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

func check_flight(avatar: Avatar, game: Node) -> int:
	var actor := avatar.horse_visual
	for flags: int in [0, 0x40, 0x04, 0x44]:
		actor.set_native_combat_flags(flags)
		for variation: int in [0, 1, 127]:
			assert(Dispatch.dispatch(avatar, decode(game, 4, 5, variation), true, flags))
			var expected := "GargoyleWingFeint" if flags == 0x40 and variation % 2 == 1 else "GargoyleWingWatch"
			assert(actor.current_clip == expected)
	actor.set_native_combat_flags(0)
	return 12

func start_fit(actor: Node3D, avatar: Avatar, request: Dictionary) -> void:
	actor.animator.stop()
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	actor.animator.advance(.19)
	assert(Dispatch.dispatch(avatar, request, true, 0x40))
	actor.animator.advance(.14)

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
	var skin: Dictionary = actor.gesture_support.skin if actor.native_body in [4, 31] else actor.gesture_ground.skin
	var lowest := INF
	var highest := -INF
	var gap := INF
	for i in 31:
		move_to(actor, i / 30.0)
		gap = minf(gap, Ground.minimum_plane_gap(skin, actor.skeleton, actor.skeleton.global_transform,
			floor.position, floor.basis.y))
		var motion := (bone(actor, "bip01 neck") - floor.position).dot(floor.basis.y)
		match actor.native_body:
			4:
				motion = bone(actor, "gargoyle l wing4").distance_to(bone(actor, "gargoyle r wing4"))
			74:
				motion = bone(actor, "imp_l_wing 02").distance_to(bone(actor, "imp_r_wing 02"))
			31:
				assert(actor.chain.visible == (clip == "HeadlessCrookedAlert" or i >= 3))
				if actor.chain.visible and DisplayServer.get_name() != "headless":
					var links: MultiMesh = actor.chain.multimesh
					assert(actor.model.to_global(links.get_instance_transform(0).origin).distance_to(bone(actor, "bip01 neck")) < .002)
					assert(actor.model.to_global(links.get_instance_transform(links.instance_count - 1).origin).distance_to(bone(actor, "bip01 l hand")) < .002)
		lowest = minf(lowest, motion)
		highest = maxf(highest, motion)
	assert(gap >= .0019, "%s slope %s gap %f" % [clip, floor.rotation, gap])
	return {"gap": gap, "minimum": lowest, "maximum": highest}

func review_fall(actor: Node3D, avatar: Avatar, floor: StaticBody3D, request: Dictionary,
		phase: float, installed: bool) -> Dictionary:
	start_fit(actor, avatar, request)
	move_to(actor, phase)
	var prior := bone(actor, "bip01 neck")
	var fall := create_fit(actor.native_body, actor.treatment, installed)
	fall.global_transform = actor.global_transform
	fall.model.transform = actor.model.transform
	fall.dead = true
	fall.contact.enabled = false
	var duration: float = fall.begin_death_from(actor)
	var jump := prior.distance_to(bone(fall, "bip01 neck"))
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
