# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-lich-gaman-enhanced.gd"

const WingBake := preload("bake-drake-walrus-enhanced.gd")
const WingRenderer := WingBake.Stage + "SourceEnhancedDrakeVisual.gd"
const WingModes := {60: {"0": {"5": ["DrakeTailScan", "DrakeBroadWingbeat"],
	"8": ["DrakeSingleWingLift"], "15": ["DrakeFoldedTakeoff"]}, "1": {"5": ["DrakeTailScan"]}}}

func run() -> void:
	var installed := "--installed" in OS.get_cmdline_user_args()
	var bases := {}
	for body: int in WingModes:
		bases[body] = Registry.entry(body)
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var evidence := {}
	for body: int in WingModes:
		var base: Dictionary = bases[body]
		var row := Registry.entry(body) if installed else wing_row(body, base)
		assert(row.enhanced_source_action_groups == WingModes[body] and row.flight_falls_back_to_combat)
		Registry.entries[body] = row
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		var receipt := await review_wings(game, body, base, row, installed)
		if receipt.is_empty():
			quit(1)
			return
		evidence[str(body)] = receipt
		Registry.entries[body] = base
	game.free()
	if not installed:
		var output := FileAccess.open(WingBake.Stage + "drake-terrain-receipt.json", FileAccess.WRITE)
		assert(output != null)
		output.store_string(JSON.stringify({"bodies": evidence, "script_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		output.close()
	quit()

static func wing_row(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = WingModes[body]
	row.archive_grounded_gestures = WingBake.DrakeClips.values()
	row.flight_falls_back_to_combat = true
	for treatment: String in row.assets:
		row.assets[treatment] = WingBake.Stage + "%d-%s.scn" % [body, treatment]
	return row

func make_actor(body: int, treatment: String, installed: bool) -> Node3D:
	var actor: Node3D = Registry.create(body) if installed else load(WingRenderer).new()
	actor.entry = Registry.entry(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor

func review_wings(game: Node, body: int, base: Dictionary, row: Dictionary, installed: bool) -> Dictionary:
	var result := {"decoded": 0, "classic": 0, "poses": 0, "falls": 0, "air_falls": 0,
		"maximum_death_jump": 0.0, "minimum_ground_gap": INF, "minimum_held_air_gap": INF, "hashes": {}, "hues": 0}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := make_actor(body, treatment, installed)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				verify_retained(actor, base)
				var counts := check_routes(avatar, game, body, WingModes[body])
				result.decoded += counts.x + check_flight_routes(actor, avatar, game)
				result.classic += counts.y
				result.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				check_retained_breath(actor, avatar, game)
			var played := {}
			for kind: String in WingModes[body]["0"]:
				var options: Array = WingModes[body]["0"][kind]
				for variant in options.size():
					var clip: String = options[variant]
					if played.has(clip):
						continue
					played[clip] = true
					var request := decode(game, body, int(kind), variant)
					for flags: int in [64, 68]:
						var air := flags == 68
						var prior_altitude := start_wing_fit(actor, avatar, request, flags, floor)
						assert(actor.current_clip == clip and actor.airborne_fit == air)
						for sample in 31:
							move_to(actor, sample / 30.0)
							var gap := wing_gap(actor, floor)
							assert(gap >= .0029, "%s flight %s pose %d slope %s penetrates %.6f" %
								[clip, air, sample, tilt, gap])
							if air and actor.animator.current_animation_position >= .16:
								assert(gap >= maxf(.6499, prior_altitude - .0001), "%s lost altitude: %.6f from %.6f" % [clip, gap, prior_altitude])
								result.minimum_held_air_gap = minf(result.minimum_held_air_gap, gap)
							elif not air:
								result.minimum_ground_gap = minf(result.minimum_ground_gap, gap)
							result.poses += 1
						for phase: float in [.10, .58]:
							start_wing_fit(actor, avatar, request, flags, floor)
							move_to(actor, phase)
							var jump := review_wing_fall(actor, floor, phase, air, installed)
							assert(jump >= 0.0)
							result.maximum_death_jump = maxf(result.maximum_death_jump, jump)
							result.falls += 1
							result.air_falls += int(air)
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
	assert(result.poses == row.archive_grounded_gestures.size() * 30 * 31
		and result.falls == row.archive_grounded_gestures.size() * 60)
	print("DRAKE WINGED TERRAIN ", body, ": ", result)
	return result

func check_flight_routes(actor: Node3D, avatar: Avatar, game: Node) -> int:
	var count := 0
	var combat: Dictionary = WingModes[actor.native_body]["0"]
	for flags: int in [4, 68]:
		actor.set_native_combat_flags(flags)
		for kind: String in combat:
			for variant: int in [0, 1, 2, 127]:
				var expected: Array = combat[kind]
				assert(Dispatch.dispatch(avatar, decode(game, actor.native_body, int(kind), variant), true, flags))
				assert(actor.current_clip == expected[variant % expected.size()] and actor.airborne_fit and not actor.contact.enabled)
				count += 1
	return count

func start_wing_fit(actor: Node3D, avatar: Avatar, request: Dictionary, flags: int, floor: StaticBody3D) -> float:
	actor.animator.stop()
	actor.action_remaining = 0.0
	actor.set_native_combat_flags(flags)
	if (flags & 4) != 0:
		actor.current_clip = "Fly"
		actor.play("Fly", 0.0)
	else:
		actor.play_gait(false, 0.0)
	actor.animator.advance(.19)
	var altitude := wing_gap(actor, floor)
	assert(Dispatch.dispatch(avatar, request, true, flags))
	actor.animator.advance(.14)
	return altitude

func wing_gap(actor: Node3D, floor: StaticBody3D) -> float:
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	return Ground.minimum_plane_gap(actor.gesture_skin, rig, rig.global_transform, floor.position, floor.basis.y)

func review_wing_fall(actor: Node3D, floor: StaticBody3D, phase: float, air: bool, installed: bool) -> float:
	var joints := ["bip01 head", "bip01 tail3", "box03", "box08"]
	var prior: Array[Vector3] = []
	for label: String in joints:
		prior.append(bone(actor, label))
	var fall := make_actor(actor.native_body, actor.treatment, installed)
	fall.global_transform = actor.global_transform
	fall.model.transform = actor.model.transform
	fall.dead = true
	fall.contact.enabled = false
	var duration: float = fall.begin_death_from(actor)
	assert(fall.current_clip == ("AirDeath" if air else "Death"))
	var jump := 0.0
	for i in joints.size():
		jump = maxf(jump, prior[i].distance_to(bone(fall, joints[i])))
	assert(duration > 0.0 and jump < .002, "%s flight %s falls at %.2f slope %s jump %.6f" %
		[actor.current_clip, air, phase, floor.rotation, jump])
	for i in 31:
		fall.animator.seek(duration * i / 30.0, true)
		assert(wing_gap(fall, floor) >= .0019)
	var snapshot := Snapshot.capture(fall, fall.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	corpse.free()
	fall.free()
	return jump

func check_retained_breath(actor: Node3D, avatar: Avatar, game: Node) -> void:
	actor.set_native_combat_flags(64)
	assert(Dispatch.dispatch(avatar, decode(game, 60, 8, 0), true, 64))
	assert(actor.current_clip == "DrakeSingleWingLift")
	assert(Classic.dispatch(avatar, {"protocol": "classic", "body": 60, "serial": 60,
		"action": 12, "frames": 5, "repeat_count": 1, "delay": 0}))
	actor.animator.advance(.14)
	assert(actor.current_clip == "DragonBreath" and actor.action_remaining >= actor.animator.current_animation_length)
	var muzzle: Variant = actor.fire_breath_origin()
	assert(muzzle is Vector3 and (muzzle as Vector3).distance_to(bone(actor, "box15")) < .00001)
