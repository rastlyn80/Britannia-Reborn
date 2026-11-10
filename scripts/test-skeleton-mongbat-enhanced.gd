# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/skeleton-mongbat/"
const SkeletonVisual := preload("res://Presentation/SourceEnhancedSkeletonVisual.gd")
const MongbatVisual := preload("res://Presentation/SourceEnhancedMongbatVisual.gd")
const SkeletonBake := preload("res://../scripts/bake-skeleton-enhanced.gd")
const MongbatBake := preload("res://../scripts/bake-mongbat-enhanced.gd")
const SkeletonModes := {"0": {
	"5": ["SkeletonSkullCheck", "SkeletonLooseGuard"], "8": ["SkeletonReadyStagger"],
	"11": ["SkeletonCastingStep", "SkeletonCastingStep", "SkeletonCastingStep"], "15": ["SkeletonAssemble"],
}, "1": {"5": ["SkeletonSkullCheck"]}}
const MongbatModes := {"0": {
	"5": ["MongbatQuietHover", "MongbatHoverRebalance"], "8": ["MongbatWingAlert"],
	"11": ["MongbatDivingSwoop", "MongbatDivingSwoop", "MongbatDivingSwoop"], "15": ["MongbatUnfoldAndRise"],
}, "1": {"5": ["MongbatQuietHover"]}}
const Choices := [[4, 11, 0], [23, 15, 0], [26, 5, 0], [27, 5, 1], [28, 8, 0]]
var installed := false

func run() -> void:
	var bases := {50: Registry.entry(50), 39: Registry.entry(39)}
	installed = "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var results := {}
	for body: int in [50, 39]:
		var result := await review_body(game, body, bases[body])
		assert(result.has("routes"), "Body %d failed playback" % body)
		results[str(body)] = result
	game.free()
	if not installed:
		var report := FileAccess.open(Stage + "skeleton-mongbat-candidate.json", FileAccess.WRITE)
		assert(report != null)
		report.store_string(JSON.stringify({"bodies": results, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		report.close()
	quit()

func review_body(game: Node, body: int, base: Dictionary) -> Dictionary:
	var row := Registry.entry(body) if installed else base.duplicate(true)
	var modes: Dictionary = SkeletonModes if body == 50 else MongbatModes
	var clips: Dictionary = SkeletonBake.SkeletonClips if body == 50 else MongbatBake.BatClips
	if not installed:
		for treatment: String in row.assets:
			row.assets[treatment] = Stage + "%d-%s.scn" % [body, treatment]
		row.enhanced_source_action_groups = modes
		row.archive_grounded_gestures = clips.values()
		if body == 39:
			row.flight_falls_back_to_combat = true
		Registry.entries[body] = row
	assert(row.enhanced_source_action_groups == modes)
	game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
	var counts := Vector2i.ZERO
	var cases := 0
	var gaps := {}
	var interrupts := 0
	var hashes := {}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor: Node3D = create_actor(row, body, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				Bake.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
				hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
				counts += check_routes(avatar, game, body, modes)
				if body == 39:
					counts += check_flight_routes(avatar, game, modes["0"])
			for selection: Array in Choices:
				var clip: String = clips[selection[0]]
				var packet := decode(game, body, selection[1], selection[2])
				var gap := review_pose(avatar, floor, packet, clip)
				assert(gap > .001, "%s clips the slope at %s, %s: %f" % [clip, tilt, treatment, gap])
				gaps[clip] = minf(gap, gaps.get(clip, INF))
				cases += 31
			interrupts += check_interruptions(game, avatar, row, body, treatment)
			avatar.free()
			free_visual(actor)
		floor.free()
		await physics_frame
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(body, hue)
		assert(corpse != null and corpse.get_meta("static_cadaver") and corpse.get_meta("native_hue") == hue)
		assert(corpse.get_meta("graphic_id") == 0x2006 and corpse.get_meta("corpse_body") == body)
		assert(corpse.find_child("AssemblyPieces", true, false) == null)
		corpse.free()
	Registry.entries[body] = base
	assert(counts == (Vector2i(96, 72) if body == 50 else Vector2i(192, 144)) and cases == 2325)
	print("RANKED CREATURE TERRAIN ", body, ": ", counts, " decoded comparisons, ",
		cases, " supported poses, ", interrupts, " interrupts, gaps ", gaps)
	return {"routes": counts.x, "classic_comparisons": counts.y, "terrain": cases, "gaps": gaps,
		"interruptions": interrupts, "static_corpse_hues": 3, "scene_sha256": hashes}

func check_flight_routes(avatar: Avatar, game: Node, combat: Dictionary) -> Vector2i:
	var counts := Vector2i.ZERO
	for flags: int in [4, 0x44]:
		for kind: String in combat:
			var choices: Array = combat[kind]
			for variant: int in [0, 1, 2, 127]:
				assert(Dispatch.dispatch(avatar, decode(game, 39, int(kind), variant), true, flags))
				assert(avatar.horse_visual.current_clip == choices[variant % choices.size()])
				counts.x += 1
			for variant: int in [0, 128, 255]:
				var packet := decode(game, 39, int(kind), variant)
				var result := Classic.dispatch(avatar, packet)
				var clip: String = avatar.horse_visual.current_clip
				assert(Dispatch.dispatch(avatar, packet, variant >= 128, flags) == result)
				assert(avatar.horse_visual.current_clip == clip)
				counts.y += 1
	return counts

func create_actor(row: Dictionary, body: int, treatment: String) -> Node3D:
	var actor: Node3D = Registry.create(body) if installed else (SkeletonVisual.new() if body == 50 else MongbatVisual.new())
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	return actor

func review_pose(avatar: Avatar, floor: StaticBody3D, packet: Dictionary, expected: String) -> float:
	var actor := avatar.horse_visual
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var meshes: Array[Node] = actor.model.find_children("*", "MeshInstance3D", true, false)
	var body := meshes[0] as MeshInstance3D
	var skin := Ground.skin_points(body, rig)
	var anchor: Transform3D = actor.global_transform
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	assert(Dispatch.dispatch(avatar, packet, true, 0x40) and actor.current_clip == expected)
	player.advance(.13)
	var minimum := INF
	for i in 31:
		player.seek(player.current_animation_length * i / 30.0, true)
		for j in 12:
			actor._physics_process(1.0 / 60.0)
		actor.contact._process_modification_with_delta(1.0 / 60.0)
		rig.force_update_all_bone_transforms()
		actor.contact.modification_processed.emit()
		if body.is_visible_in_tree():
			minimum = minf(minimum, Ground.minimum_plane_gap(skin, rig, rig.global_transform, floor.position, floor.basis.y))
		else:
			for piece: MeshInstance3D in meshes:
				if piece.is_visible_in_tree():
					var points: PackedVector3Array = piece.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
					for vertex in points:
						minimum = minf(minimum, (piece.to_global(vertex) - floor.position).dot(floor.basis.y))
		assert(actor.global_transform.is_equal_approx(anchor) and not actor.contact.contacts.is_empty())
	return minimum

func check_interruptions(game: Node, avatar: Avatar, row: Dictionary, body: int, treatment: String) -> int:
	var source := avatar.horse_visual
	var player: AnimationPlayer = source.animator
	assert(Dispatch.dispatch(avatar, decode(game, body, 15, 0), true, 0x40))
	player.advance(.13)
	if body == 50:
		player.seek(.30, true)
		assert(source.pieces.visible and not source.living_mesh.visible)
		assert(Dispatch.dispatch(avatar, decode(game, body, 0, 0), false, 0x40))
		player.advance(.15)
		assert(not source.pieces.visible and source.living_mesh.visible and not source.dead)
		return 1
	for case: Array in [[.16, "Death"], [.56, "AirDeath"]]:
		player.seek(case[0], true)
		var visual := create_actor(row, body, treatment)
		var duration: float = visual.begin_death_from(source)
		assert(duration > 0.0 and visual.current_clip == case[1])
		free_visual(visual)
	return 2

func free_visual(actor: Node3D) -> void:
	root.remove_child(actor)
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(surface, null)
	actor.free()
