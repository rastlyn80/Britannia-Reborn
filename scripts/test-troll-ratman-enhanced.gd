# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/troll-ratman/"
const RatmanRenderer := "res://Presentation/SourceEnhancedRatmanVisual.gd"
const TrollRenderer := "res://Presentation/SourceEnhancedTrollVisual.gd"
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Modes := {
	53: {"0": {"5": ["TrollMeasure", "TrollOpenGuard"], "8": ["TrollBraceAlert"],
		"11": ["TrollOpenHandSlam", "TrollOpenHandSlam", "TrollOpenHandSlam"], "15": ["TrollBraceAndRise"]},
		"1": {"5": ["TrollMeasure"]}},
	42: {"0": {"5": ["RatmanQuietGuard", "RatmanAxeCheck"], "8": ["RatmanAxeAlert"],
		"11": ["RatmanOverheadAxe", "RatmanOverheadAxe", "RatmanOverheadAxe"], "15": ["RatmanAxeSomersault"]},
		"1": {"5": ["RatmanQuietGuard"]}},
}
const Poses := [[5, 0], [5, 1], [8, 0], [11, 0], [15, 0]]
const Axe := "EnhancedRatmanAxe"
var installed := false

func run() -> void:
	var bases := {53: Registry.entry(53), 42: Registry.entry(42)}
	installed = "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var evidence := {}
	for body: int in Modes:
		var report := await review(game, body, bases[body])
		assert(report.has("routes"))
		evidence[str(body)] = report
	game.free()
	if not installed:
		var file := FileAccess.open(Stage + "troll-ratman-candidate.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"bodies": evidence, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	quit()

func review(game: Node, body: int, base: Dictionary) -> Dictionary:
	var modes: Dictionary = Modes[body]
	var row := Registry.entry(body) if installed else base.duplicate(true)
	if not installed:
		row.enhanced_source_action_groups = modes
		row.archive_grounded_gestures = Poses.map(func(pair: Array): return modes["0"][str(pair[0])][pair[1]])
		row.presentation_script = RatmanRenderer if body == 42 else TrollRenderer
		for treatment: String in row.assets:
			row.assets[treatment] = Stage + "%d-%s.scn" % [body, treatment]
		Registry.entries[body] = row
	assert(row.enhanced_source_action_groups == modes)
	game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
	var counts := Vector2i.ZERO
	var hashes := {}
	var gaps := {}
	var fall_minimum := INF
	var handoff_gap := 0.0
	var lift := 0.0
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := create_actor(row, body, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				check_retained_tracks(actor.animator, base.assets[treatment], body == 42)
				counts += check_routes(avatar, game, body, modes)
				hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
			for variant: Array in Poses:
				var clip: String = modes["0"][str(variant[0])][variant[1]]
				var gap := sample(avatar, floor, decode(game, body, variant[0], variant[1]), clip)
				gaps[clip] = minf(gap, gaps.get(clip, INF))
			if body == 42:
				for mode: int in [2, 3, 15]:
					var result := test_fall(game, row, treatment, mode, floor)
					fall_minimum = minf(fall_minimum, result.x)
					handoff_gap = maxf(handoff_gap, result.y)
					lift = maxf(lift, result.z)
			avatar.free()
			free_visual(actor)
		floor.free()
		await physics_frame
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(body, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("corpse_body") == body)
		assert(corpse.get_meta("native_hue") == hue and corpse.get_meta("graphic_id") == 0x2006)
		assert((corpse.find_child(Axe, true, false) != null) == (body == 42))
		if body == 42:
			var axe: MeshInstance3D = corpse.find_child(Axe, true, false)
			assert(axe.get_active_material(0) is StandardMaterial3D)
		corpse.free()
	Registry.entries[body] = base
	print("TROLL/RATMAN ", body, " ", counts, " gesture gaps ", gaps, " fall ", fall_minimum, " handoff ", handoff_gap, " extra axe lift ", lift)
	assert(counts == Vector2i(96, 72) and gaps.size() == 5)
	assert(gaps.values().min() > .001)
	var report := {"routes": counts.x, "classic_comparisons": counts.y, "terrain": 2325, "gaps": gaps,
		"corpse_hues": 3, "scene_sha256": hashes}
	if body == 42:
		assert(fall_minimum > .001 and handoff_gap < .025 and lift < .050)
		report.merge({"fall_poses": 1845, "handoffs": 45, "fall_minimum": fall_minimum,
			"handoff_gap": handoff_gap, "extra_axe_lift": lift})
	return report

func create_actor(row: Dictionary, body: int, treatment: String) -> Node3D:
	var actor := Registry.create(body)
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	if body == 42:
		var axe: MeshInstance3D = actor.model.find_child(Axe, true, false)
		assert(axe.get_surface_override_material(0) == null)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor

func test_fall(game: Node, row: Dictionary, treatment: String, mode: int, floor: StaticBody3D) -> Vector3:
	var source := create_actor(row, 42, treatment)
	var avatar := Avatar.new()
	avatar.horse_visual = source
	var player: AnimationPlayer = source.animator
	if mode == 15:
		assert(Dispatch.dispatch(avatar, decode(game, 42, 15, 0), true, 64))
	else:
		var packet := PackedByteArray([0x6e])
		packet.append_array(Wire.uint_be(42, 4))
		packet.append_array(Wire.uint_be(mode, 2))
		packet.append_array(PackedByteArray([0, 5, 0, 1, 0, 0, 0]))
		game._handle(packet)
		assert(Classic.dispatch(avatar, game.last_mobile_actions[42]))
	var expected := "Death2" if mode == 2 else "Death"
	player.advance(.13)
	player.seek(player.current_animation_length * (.36 if mode == 15 else .5), true)
	if mode == 15:
		for frame in 15:
			source._physics_process(1.0 / 60.0)
		source.contact._process_modification_with_delta(1.0 / 60.0)
		source.contact.modification_processed.emit()
	var before := grip(source)
	var elapsed := player.current_animation_position
	var fallen := create_actor(row, 42, treatment)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	assert(fallen.begin_death_from(source) > .0 and fallen.current_clip == expected)
	assert(absf(fallen.animator.current_animation_position - (0.0 if mode == 15 else elapsed)) < .002)
	var drift := before.distance_to(grip(fallen))
	var minimum := INF
	var lift := 0.0
	var death_player: AnimationPlayer = fallen.animator
	for frame in 41:
		death_player.seek(lerpf(0.0 if mode == 15 else elapsed, death_player.current_animation_length, frame / 40.0), true)
		var plane := {"position": floor.position, "normal": floor.basis.y}
		var body_gap := Ground.minimum_plane_gap(fallen.fall.skin, fallen.skeleton, fallen.skeleton.global_transform,
			plane.position, plane.normal)
		minimum = minf(minimum, minf(body_gap, fallen.axe_gap(plane)))
		lift = maxf(lift, fallen.axe_lift.length())
		grip(fallen)
		assert(fallen.global_position.is_zero_approx())
	var saved := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not saved.is_empty())
	var corpse: Node3D = saved.scene.instantiate()
	root.add_child(corpse)
	corpse.global_transform = saved.placement
	assert(corpse.get_meta("death_clip") == expected and corpse.get_meta("native_hue") == 0x8035)
	assert(corpse.find_child(Axe, true, false) != null and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	for part: MeshInstance3D in corpse.find_children("*", "MeshInstance3D", true, false):
		for index in part.mesh.get_surface_count():
			var points: PackedVector3Array = part.mesh.surface_get_arrays(index)[Mesh.ARRAY_VERTEX]
			for point: Vector3 in points:
				assert((part.to_global(point) - floor.position).dot(floor.basis.y) >= .001)
	corpse.free()
	free_visual(fallen)
	avatar.free()
	free_visual(source)
	return Vector3(minimum, drift, lift)

func grip(actor: Node3D) -> Vector3:
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	var joint: int = actor.axe_joint
	var socket := rig.get_bone_global_pose(rig.get_bone_parent(joint))
	assert(rig.get_bone_global_pose(joint).origin.distance_to(socket * rig.get_bone_rest(joint).origin) < .0001)
	return rig.to_global(socket.origin)

func free_visual(actor: Node3D) -> void:
	root.remove_child(actor)
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(surface, null)
	actor.free()

func check_retained_tracks(player: AnimationPlayer, path: String, armed: bool) -> void:
	var source := (load(path) as PackedScene).instantiate()
	var original := source.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for name: String in original.get_animation_list():
		var prior := original.get_animation(name)
		var current := player.get_animation(name)
		var count := prior.get_track_count()
		assert(current.length == prior.length and current.get_track_count() == count + int(armed))
		for track in count:
			assert(prior.track_get_path(track) == current.track_get_path(track))
			assert(prior.get("tracks/%d/keys" % track) == current.get("tracks/%d/keys" % track))
		if armed:
			assert(current.track_get_path(count).get_subname(0) == "ratman enhanced axe")
	source.free()
