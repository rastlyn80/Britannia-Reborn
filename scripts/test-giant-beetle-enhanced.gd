# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Fit := preload("bake-giant-beetle-enhanced.gd")
const Visual := preload("res://Presentation/SourceEnhancedGiantBeetleVisual.gd")
const Actions := preload("res://Presentation/EnhancedCreatureAttackActions.gd")
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Renderer := "res://Presentation/SourceEnhancedGiantBeetleVisual.gd"
const Body := 791
const Bite := "BeetleWingedBite"
const Hook := "BeetleWingedHook"
const Groups := {"0": {"2": ["Idle", "BeetleWingedIdle"], "3": ["Death2", "Death"],
	"4": ["BeetleWingedHit"], "5": ["BeetleWingedFlare", "BeetleWingedDisplay"],
	"8": ["BeetleRaiseWings"], "11": [Bite, Bite, Bite], "14": ["Idle"], "15": ["Idle"]},
	"1": {"5": ["BeetleWingedFlare"]}}
const Attacks := {"0": [Bite, Hook, Bite], "1": [Bite], "2": [Bite], "9": [Bite],
	"255": [Bite, Hook, Bite, Bite, Bite, Bite]}
const Landmarks := ["bip01 head", "bip01 pelvis", "dummy02", "hindwing_0", "hindwing_1"]


func run() -> void:
	var base := Registry.entry(Body)
	var row := base.duplicate(true)
	row.presentation_script = Renderer
	row.enhanced_source_action_groups = Groups
	row.enhanced_attack_subactions = Attacks
	for treatment: String in row.assets:
		row.assets[treatment] = Fit.Destination + "%d-%s.scn" % [Body, treatment]
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		var rows := Installed.read_rows(Installed.MANIFEST, Installed.SCENES)
		assert(rows.has(Body))
		row = rows[Body]
		assert(row.presentation_script == Renderer and row.enhanced_source_action_groups == Groups and row.enhanced_attack_subactions == Attacks)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[Body] = {"serial": Body, "body": Body, "hue": 0x8035}
	var visual_script: GDScript = Visual
	var report := {"routes": 0, "terrain_poses": 0, "falls": 0, "frozen": 0, "maximum_jump": 0.0,
		"minimum_floor": INF, "minimum_fall_floor": INF, "hashes": {},
		"renderer_sha256": FileAccess.get_sha256(visual_script.resource_path)}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var beetle := actor(row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = beetle
			if tilt == Vector3.ZERO:
				report.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				report.routes += check_wire(game, beetle, avatar)
			check_gaits(beetle, report, floor.global_basis.y)
			for variant in [0, 1]:
				for phase: float in [.20, .64]:
					check_fall(game, beetle, avatar, row, treatment, variant, phase, report)
			beetle.free()
			avatar.free()
		floor.free()
	game.free()
	assert(report.routes == 387 and report.terrain_poses == 2565 and report.falls == 60 and report.frozen == 60)
	if not installed:
		var output := FileAccess.open(Fit.Destination + "beetle-enhanced-receipt.json", FileAccess.WRITE)
		assert(output != null)
		output.store_string(JSON.stringify(report, "\t"))
		output.close()
	print("GIANT BEETLE ENHANCED ", report)
	quit()


func actor(row: Dictionary, treatment: String) -> Node3D:
	var result := Visual.new()
	result.entry = row
	result.treatment = treatment
	root.add_child(result)
	result.apply_identity(Body, 0x8035)
	result.set_process(false)
	result.set_physics_process(false)
	result.contact.active = false
	result.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return result


func action(game: Node, kind: int, subaction: int, variant: int) -> Dictionary:
	var bytes := PackedByteArray([0xe2])
	bytes.append_array(Wire.uint_be(Body, 4))
	bytes.append_array(PackedByteArray([0, kind, subaction >> 8, subaction & 0xff, variant]))
	game._handle(bytes)
	return game.last_mobile_actions[Body]


func reset_actor(beetle: Node3D) -> void:
	beetle.dead = false
	beetle.action_remaining = 0.0
	beetle.alternate_fall.plane.clear()
	beetle.model.position -= beetle.alternate_fall.shift
	beetle.alternate_fall.shift = Vector3.ZERO
	beetle.contact.contacts.clear()
	beetle.play("Idle", 0.0)
	beetle.current_clip = "Idle"
	beetle.animator.advance(0.0)


func check_wire(game: Node, beetle: Node3D, avatar: Avatar) -> int:
	var checks := 0
	for flags in [0, 0x40]:
		var mode := "1" if flags == 0 else "0"
		for kind: String in Groups["0"]:
			var choices: Array = Groups[mode].get(kind, Groups["0"][kind])
			for variant in [0, 1, 2, 127]:
				reset_actor(beetle)
				assert(Actions.dispatch(avatar, action(game, int(kind), 0, variant), true, flags))
				assert(beetle.current_clip == choices[variant % choices.size()] and beetle.dead == (kind == "3"))
				checks += 1
		for subaction in [0, 1, 2, 9, 37, 0x100, 0x101, 0x1ff]:
			var choices: Array = Attacks.get(str(subaction & 255), Attacks["255"])
			for variant in [0, 1, 2, 127]:
				reset_actor(beetle)
				assert(Actions.dispatch(avatar, action(game, 0, subaction, variant), true, flags))
				assert(beetle.current_clip == choices[variant % choices.size()] and not beetle.dead)
				checks += 1
	reset_actor(beetle)
	beetle.set_native_combat_flags(0)
	beetle.set_native_combat_flags(0x40)
	assert(beetle.current_clip == Visual.Raise and beetle.action_remaining > 0.0)
	return checks + 1


func check_gaits(beetle: Node3D, report: Dictionary, normal: Vector3) -> void:
	for mode in [0, 1, 2]:
		reset_actor(beetle)
		beetle.combat_flags = 0x40 if mode == 0 else 0
		beetle.apply_identity(Body, 0x8035, Visual.GiantBeetleMount if mode == 2 else 0)
		var clips: Array = [Visual.CombatGaits, Visual.PeaceGaits, Visual.MountedGaits][mode]
		for index in 3:
			beetle.play_gait(index != 0, [0.0, 1.8, 5.5][index])
			assert(beetle.current_clip == clips[index])
			beetle.animator.advance(.22)
			for sample in 19:
				beetle.animator.seek(beetle.animator.current_animation_length * sample / 19.0, true)
				beetle.skeleton.force_update_all_bone_transforms()
				var wing: int = beetle.skeleton.find_bone("hindwing_0")
				var angle: float = beetle.skeleton.get_bone_pose_rotation(wing).angle_to(beetle.skeleton.get_bone_rest(wing).basis.get_rotation_quaternion())
				assert(angle > .5 if mode == 0 and index < 2 else angle < .001, "%s wing angle %.5f" % [clips[index], angle])
				beetle.contact.contacts[0] = {"position": Vector3.ZERO, "normal": normal}
				beetle.support_control_plane()
				var gap := Ground.minimum_plane_gap(beetle.alternate_fall.skin, beetle.skeleton, beetle.skeleton.global_transform, Vector3.ZERO, normal)
				assert(gap >= -.001, "%s treatment %s floor %.6f" % [beetle.current_clip, beetle.treatment, gap])
				report.minimum_floor = minf(report.minimum_floor, gap)
				report.terrain_poses += 1
	beetle.apply_identity(Body, 0x8035)


func landmarks(beetle: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	for label: String in Landmarks:
		points.append(beetle.skeleton.to_global(beetle.skeleton.get_bone_global_pose(beetle.skeleton.find_bone(label)).origin))
	return points


func check_fall(game: Node, beetle: Node3D, avatar: Avatar, row: Dictionary, treatment: String,
		variant: int, phase: float, report: Dictionary) -> void:
	reset_actor(beetle)
	beetle.combat_flags = 0x40
	beetle.play_gait(true, 1.8)
	beetle.animator.advance(.23)
	assert(Actions.dispatch(avatar, action(game, 3, 0, variant), true, 0x40))
	beetle.animator.advance(.17)
	beetle.animator.seek(phase * beetle.animator.current_animation_length, true)
	beetle.skeleton.force_update_all_bone_transforms()
	var before := landmarks(beetle)
	var corpse := actor(row, treatment)
	assert(corpse.begin_death_from(beetle) > 0.0)
	assert(corpse.dead and corpse.current_clip == ("Death2" if variant == 0 else "Death"))
	var after := landmarks(corpse)
	for i in before.size():
		var jump := before[i].distance_to(after[i])
		assert(jump < .001, "%s %s %s moved by %.6f" % [treatment, corpse.current_clip, Landmarks[i], jump])
		report.maximum_jump = maxf(report.maximum_jump, jump)
	for sample in 16:
		var time: float = lerpf(phase, 1.0, float(sample + 1) / 16.0) * corpse.animator.current_animation_length
		corpse.animator.seek(time, true)
		var floor: Dictionary = corpse.alternate_fall.plane
		var gap := Ground.minimum_plane_gap(corpse.alternate_fall.skin, corpse.skeleton, corpse.skeleton.global_transform, floor.position, floor.normal)
		assert(gap >= .0018, "%s fallen shell floor %.6f" % [corpse.current_clip, gap])
		report.minimum_fall_floor = minf(report.minimum_fall_floor, gap)
	var frozen := Snapshot.capture(corpse, corpse.corpse_snapshot_floor())
	assert(not frozen.is_empty())
	var static_body: Node3D = frozen.scene.instantiate()
	assert(static_body.get_child_count() == 3 and static_body.find_children("*", "Skeleton3D", true, false).is_empty())
	corpse.apply_identity(Body, 0x035)
	var dyed := Corpses.freeze(corpse)
	assert(dyed != null and Snapshot.use_current_materials(static_body, dyed, []) and static_body.get_meta("native_hue") == 0x035)
	dyed.free()
	static_body.free()
	corpse.free()
	report.falls += 1
	report.frozen += 1
