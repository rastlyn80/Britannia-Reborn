# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Mage := preload("res://Presentation/SourceEnhancedMeerMageVisual.gd")
const MageFit := preload("bake-meer-mage-enhanced.gd")
const Actions := preload("res://Presentation/EnhancedCreatureAttackActions.gd")
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Body := 770
const Dye := 0x8035
const First := "MeerMageCrossingStrike"
const Second := "MeerMageRaisedStrike"
const Third := "MeerMageShortThrust"
const Groups := {"0": {"2": ["MeerMageCrossGuard", "MeerMageCrossGuard"], "3": ["Death", "Death2"],
	"4": ["MeerMageRecoil"], "5": ["MeerMageHipCheck", Mage.Stand], "8": [Mage.Stand],
	"11": [First, First, First], "14": [Mage.Stand], "15": [Mage.Stand]}, "1": {"5": ["MeerMageHipCheck"]}}
const Attacks := {"0": [First, Second, Third], "1": [First], "2": [First], "9": [First],
	"255": [First, Second, Third, First, First, First]}
const Landmarks := ["bip01 head", "bip01 l hand", "bip01 r hand", "bip01 pelvis", "bip01 l foot"]


func run() -> void:
	var row := Registry.entry(Body).duplicate(true)
	row.enhanced_source_action_groups = Groups
	row.enhanced_attack_subactions = Attacks
	var clips := MageFit.Clips.values() + [MageFit.WalkName]
	row.archive_grounded_gestures = row.get("archive_grounded_gestures", []) + clips
	row.archive_align_gesture_slope = true
	for treatment: String in row.assets:
		row.assets[treatment] = MageFit.Destination + "%d-%s.scn" % [Body, treatment]
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		var rows := Installed.read_rows(Installed.MANIFEST, Installed.SCENES)
		assert(rows.has(Body))
		row = rows[Body]
		assert(row.enhanced_source_action_groups == Groups and row.enhanced_attack_subactions == Attacks)
		assert(row.archive_align_gesture_slope and row.presentation_script.ends_with("/SourceEnhancedMeerMageVisual.gd"))
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[Body] = {"serial": Body, "body": Body, "hue": Dye}
	var render_script: GDScript = Mage
	var report := {"routes": 0, "terrain_poses": 0, "falls": 0, "fall_poses": 0, "maximum_jump": 0.0,
		"minimum_floor": INF, "minimum_fall_floor": INF, "hashes": {}, "renderer_sha256": FileAccess.get_sha256(render_script.resource_path)}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var mage := make_actor(row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = mage
			if tilt == Vector3.ZERO:
				report.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				report.routes += test_actions(mage, avatar, game)
			for clip: String in clips:
				reset(mage)
				mage.current_clip = clip
				mage.play(clip, 0.0)
				mage.animator.advance(0.0)
				for sample in 25:
					mage.animator.seek(mage.animator.current_animation_length * sample / 25.0, true)
					mage.contact.contacts[0] = {"position": floor.position, "normal": floor.basis.y}
					mage.ground_gesture.support(mage)
					var gap := Ground.minimum_plane_gap(mage.ground_gesture.skin, mage.skeleton, mage.skeleton.global_transform, floor.position, floor.basis.y)
					assert(gap >= .0018, "%s on %s has floor gap %.6f" % [clip, treatment, gap])
					report.minimum_floor = minf(report.minimum_floor, gap)
					report.terrain_poses += 1
			for parity in 2:
				for phase: float in [.24, .63]:
					assert(test_fall(mage, avatar, game, row, treatment, parity, phase, report))
			mage.free()
			avatar.free()
		floor.free()
	game.free()
	assert(report.routes == 402 and report.terrain_poses == 3000 and report.falls == 60 and report.fall_poses == 960)
	if not installed:
		var file := FileAccess.open(MageFit.Destination + "meer-mage-focused.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("MEER MAGE ENHANCED ", report)
	quit()


func make_actor(row: Dictionary, treatment: String) -> Node3D:
	var actor := Mage.new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(Body, Dye)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func reset(actor: Node3D) -> void:
	actor.ground_gesture.release(actor)
	actor.model.position -= actor.fall.shift
	actor.fall.shift = Vector3.ZERO
	actor.fall.plane.clear()
	actor.fall.blend_pose.clear()
	actor.dead = false
	actor.action_remaining = 0.0
	actor.current_clip = "Idle"
	actor.play("Idle", 0.0)
	actor.animator.advance(0.0)


func action(game: Node, kind: int, subaction: int, variant: int) -> Dictionary:
	var bytes := PackedByteArray([0xe2])
	bytes.append_array(Wire.uint_be(Body, 4))
	bytes.append_array(PackedByteArray([0, kind, subaction >> 8, subaction & 0xff, variant]))
	game._handle(bytes)
	return game.last_mobile_actions[Body]


func test_actions(mage: Node3D, avatar: Avatar, game: Node) -> int:
	var checks := 0
	for flags in [0, 64]:
		var mode := "1" if flags == 0 else "0"
		for kind: String in Groups["0"]:
			var choices: Array = Groups[mode].get(kind, Groups["0"][kind])
			for variant in [0, 1, 2, 127]:
				reset(mage)
				assert(Actions.dispatch(avatar, action(game, int(kind), 0, variant), true, flags))
				assert(mage.current_clip == choices[variant % choices.size()] and mage.dead == (kind == "3"))
				checks += 1
		for subaction in [0, 1, 2, 9, 37, 0x100, 0x101, 0x1ff]:
			var choices: Array = Attacks.get(str(subaction & 255), Attacks["255"])
			for variant in [0, 1, 2, 127]:
				reset(mage)
				assert(Actions.dispatch(avatar, action(game, 0, subaction, variant), true, flags))
				assert(mage.current_clip == choices[variant % choices.size()] and not mage.dead)
				checks += 1
		reset(mage)
		for speed: float in [0.0, 1.8, 5.5]:
			mage.play_gait(speed > 0.0, speed)
			assert(mage.current_clip == (Mage.Walk if speed == 1.8 else "Run" if speed == 5.5 else Mage.Stand))
			checks += 1
	return checks


func positions(mage: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	for label: String in Landmarks:
		points.append(mage.skeleton.to_global(mage.skeleton.get_bone_global_pose(mage.skeleton.find_bone(label)).origin))
	return points


func test_fall(mage: Node3D, avatar: Avatar, game: Node, row: Dictionary, treatment: String,
		parity: int, phase: float, report: Dictionary) -> bool:
	reset(mage)
	assert(Actions.dispatch(avatar, action(game, 3, 0, parity), true, 64))
	mage.animator.advance(.17)
	mage.animator.seek(phase * mage.animator.current_animation_length, true)
	mage.skeleton.force_update_all_bone_transforms()
	var before := positions(mage)
	var corpse := make_actor(row, treatment)
	corpse.dead = true
	corpse.contact.enabled = false
	corpse.global_transform = mage.global_transform.rotated(Vector3.UP, .31)
	corpse.model.transform = mage.model.transform
	assert(corpse.begin_death_from(mage) > 0.0)
	assert(corpse.current_clip == ("Death" if parity == 0 else "Death2"))
	var after := positions(corpse)
	for index in before.size():
		var jump := before[index].distance_to(after[index])
		assert(jump < .0025, "Meer Mage fall handoff moved %s by %.6f" % [Landmarks[index], jump])
		report.maximum_jump = maxf(report.maximum_jump, jump)
	for sample in 16:
		var time: float = lerpf(phase, 1.0, float(sample + 1) / 16.0) * corpse.animator.current_animation_length
		corpse.animator.seek(time, true)
		var plane: Dictionary = corpse.fall.plane
		var gap := Ground.minimum_plane_gap(corpse.fall.skin, corpse.skeleton, corpse.skeleton.global_transform, plane.position, plane.normal)
		assert(gap >= .0018)
		report.minimum_fall_floor = minf(report.minimum_fall_floor, gap)
		report.fall_poses += 1
	var frozen := Snapshot.capture(corpse, corpse.corpse_snapshot_floor())
	assert(not frozen.is_empty())
	var still: Node3D = frozen.scene.instantiate()
	assert(still.find_children("*", "Skeleton3D", true, false).is_empty())
	assert(still.get_meta("native_hue") == Dye)
	still.free()
	corpse.free()
	report.falls += 1
	return true
