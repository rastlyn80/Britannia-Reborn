# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const TreeVisual := preload("res://Presentation/SourceEnhancedTreefellowVisual.gd")
const Fit := preload("bake-treefellow-enhanced.gd")
const Actions := preload("res://Presentation/EnhancedCreatureAttackActions.gd")
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Body := 301
const Dye := 0x8035
const Hammer := "TreefellowBranchHammer"
const Rake := "TreefellowRakingSwipe"
const Cast := "TreefellowRootCast"
const Guard := "TreefellowBracedGuard"
const Watch := "TreefellowWoodlandWatch"
const Groups := {"0": {"2": [Guard, Guard], "3": ["Death", "Death2"], "4": ["TreefellowBarkRecoil"],
	"5": [Watch, "TreefellowCanopyLift"], "8": [TreeVisual.Ready], "11": [Cast, Cast, Cast],
	"14": ["TreefellowLowGather"], "15": ["TreefellowSlowRise"]}, "1": {"5": [Watch]}}
const Attacks := {"0": [Hammer, Rake, Hammer], "1": [Hammer], "2": [Hammer], "9": [Hammer],
	"255": [Hammer, Rake, Hammer, Hammer, Hammer, Hammer]}
const Landmarks := ["bip01 head", "bip01 l hand", "bip01 r hand", "bip01 pelvis", "box01", "bip01 l toe21"]


func run() -> void:
	var row := Registry.entry(Body).duplicate(true)
	row.enhanced_source_action_groups = Groups
	row.enhanced_attack_subactions = Attacks
	for treatment: String in row.assets:
		row.assets[treatment] = Fit.Destination + "%d-%s.scn" % [Body, treatment]
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		var rows := Installed.read_rows(Installed.MANIFEST, Installed.SCENES)
		assert(rows.has(Body))
		row = rows[Body]
		assert(row.enhanced_source_action_groups == Groups and row.enhanced_attack_subactions == Attacks)
		assert(row.presentation_script.ends_with("/SourceEnhancedTreefellowVisual.gd"))
	var clips := Fit.Clips.values() + [Fit.QuietWalk]
	clips.erase("Death2")
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[Body] = {"serial": Body, "body": Body, "hue": Dye}
	var script: GDScript = TreeVisual
	var report := {"routes": 0, "terrain_poses": 0, "falls": 0, "fall_poses": 0, "maximum_jump": 0.0,
		"minimum_floor": INF, "minimum_fall_floor": INF, "minimum_corpse_height_ratio": INF,
		"hashes": {}, "renderer_sha256": FileAccess.get_sha256(script.resource_path)}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := make_actor(row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				report.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				report.routes += test_actions(actor, avatar, game)
			for clip: String in clips:
				reset(actor)
				actor.current_clip = clip
				actor.play(clip, 0.0)
				actor.animator.advance(0.0)
				for sample in 25:
					actor.animator.seek(actor.animator.current_animation_length * sample / 25.0, true)
					actor.contact.contacts[0] = {"position": floor.position, "normal": floor.basis.y}
					actor.support_control_plane()
					var gap := Ground.minimum_plane_gap(actor.fall.skin, actor.skeleton, actor.skeleton.global_transform, floor.position, floor.basis.y)
					assert(gap >= .0004, "%s on %s has floor gap %.6f" % [clip, treatment, gap])
					report.minimum_floor = minf(report.minimum_floor, gap)
					report.terrain_poses += 1
			for phase: float in [.24, .63]:
				var flat := test_fall(actor, avatar, game, row, treatment, 0, phase, report)
				var standing := test_fall(actor, avatar, game, row, treatment, 1, phase, report)
				assert(flat > .1 and standing > flat * 1.45, "Treefellow static corpse directions must stay distinct")
				report.minimum_corpse_height_ratio = minf(report.minimum_corpse_height_ratio, standing / flat)
			actor.free()
			avatar.free()
		floor.free()
	game.free()
	assert(report.routes == 405 and report.terrain_poses == 4875 and report.falls == 60 and report.fall_poses == 960)
	if not installed:
		var file := FileAccess.open(Fit.Destination + "treefellow-focused.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("TREEFELLOW ENHANCED ", report)
	quit()


func make_actor(row: Dictionary, treatment: String) -> Node3D:
	var actor := TreeVisual.new()
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
	actor.release_clearance()
	actor.model.position -= actor.fall.shift
	actor.fall.shift = Vector3.ZERO
	actor.fall.plane.clear()
	actor.fall.blend_pose.clear()
	actor.contact.contacts.clear()
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


func test_actions(actor: Node3D, avatar: Avatar, game: Node) -> int:
	var checks := 0
	for flags in [0, 64]:
		var mode := "1" if flags == 0 else "0"
		for kind: String in Groups["0"]:
			var choices: Array = Groups[mode].get(kind, Groups["0"][kind])
			for variant in [0, 1, 2, 127]:
				reset(actor)
				assert(Actions.dispatch(avatar, action(game, int(kind), 0, variant), true, flags))
				assert(actor.current_clip == choices[variant % choices.size()] and actor.dead == (kind == "3"))
				checks += 1
		for subaction in [0, 1, 2, 9, 37, 0x100, 0x101, 0x1ff]:
			var choices: Array = Attacks.get(str(subaction & 255), Attacks["255"])
			for variant in [0, 1, 2, 127]:
				reset(actor)
				assert(Actions.dispatch(avatar, action(game, 0, subaction, variant), true, flags))
				assert(actor.current_clip == choices[variant % choices.size()] and not actor.dead)
				checks += 1
		reset(actor)
		actor.set_native_combat_flags(flags)
		if flags == 64:
			assert(actor.current_clip == TreeVisual.Ready)
			actor.action_remaining = 0.0
			checks += 1
		var gaits := [TreeVisual.CombatIdle, "Walk", "Run"] if flags else [TreeVisual.QuietIdle, TreeVisual.QuietWalk, "Run"]
		for index in 3:
			actor.play_gait(index != 0, [0.0, 1.8, 5.5][index])
			assert(actor.current_clip == gaits[index])
			checks += 1
	return checks


func positions(actor: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	for label: String in Landmarks:
		points.append(actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(label)).origin))
	return points


func test_fall(actor: Node3D, avatar: Avatar, game: Node, row: Dictionary, treatment: String,
		parity: int, phase: float, report: Dictionary) -> float:
	reset(actor)
	assert(Actions.dispatch(avatar, action(game, 3, 0, parity), true, 64))
	actor.animator.advance(.17)
	actor.animator.seek(phase * actor.animator.current_animation_length, true)
	actor.skeleton.force_update_all_bone_transforms()
	var before := positions(actor)
	var corpse := make_actor(row, treatment)
	corpse.dead = true
	corpse.contact.enabled = false
	corpse.global_transform = actor.global_transform.rotated(Vector3.UP, .31)
	corpse.model.transform = actor.model.transform
	assert(corpse.begin_death_from(actor) > 0.0)
	assert(corpse.current_clip == ("Death" if parity == 0 else "Death2"))
	var after := positions(corpse)
	for index in before.size():
		var jump := before[index].distance_to(after[index])
		assert(jump < .0025, "Treefellow fall handoff moved %s by %.6f" % [Landmarks[index], jump])
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
	assert(still.find_children("*", "Skeleton3D", true, false).is_empty() and still.get_meta("native_hue") == Dye)
	var bounds: AABB = still.get_meta("corpse_bounds")
	if treatment == "modern":
		var bark := still.get_child(0) as MeshInstance3D
		assert((bark.get_active_material(0) as ShaderMaterial).shader == TreeVisual.Bark)
		assert(not bark.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR].is_empty())
	still.free()
	corpse.free()
	report.falls += 1
	return bounds.size.y
