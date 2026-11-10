# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Batch := preload("bake-bomber-lord-enhanced.gd")
const Renderers := {182: "SourceEnhancedOrcBomberVisual.gd", 83: "SourceEnhancedOgreLordVisual.gd"}
const Bodies := [182, 83]
const Cases := {4: [11, 0], 23: [15, 0], 26: [5, 0], 27: [5, 1], 28: [8, 0]}


static func modes_for(body: int) -> Dictionary:
	var clips := Batch.Bomber if body == 182 else Batch.Lord
	return {"0": {"5": [clips[26], clips[27]], "8": [clips[28]], "11": [clips[4], clips[4], clips[4]],
		"15": [clips[23]]}, "1": {"5": [clips[26]]}}


static func row_for(body: int, base: Dictionary) -> Dictionary:
	var row := base.duplicate(true)
	row.enhanced_source_action_groups = modes_for(body)
	row.archive_grounded_gestures = (Batch.Bomber if body == 182 else Batch.Lord).values()
	for treatment: String in row.assets:
		row.assets[treatment] = Batch.Destination + "%d-%s.scn" % [body, treatment]
	return row


func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var bases := {}
	for body: int in Bodies:
		bases[body] = Registry.entry(body)
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	var result := {}
	for body: int in Bodies:
		game.entities[body] = {"serial": body, "body": body, "hue": 0x8035}
		result[str(body)] = await exercise(game, body, bases[body], installed)
		var summary: Dictionary = result[str(body)]
		assert(summary.poses == 2325 and summary.falls == 150 and summary.routes == 96 and summary.classic == 72)
		assert(summary.bomb_origins == (3 if body == 182 else 0))
	game.free()
	if not installed:
		var receipt := FileAccess.open(Batch.Destination + "runtime-receipt.json", FileAccess.WRITE)
		assert(receipt != null)
		receipt.store_string(JSON.stringify(result, "\t"))
		receipt.close()
	quit()


func create_actor(body: int, row: Dictionary, treatment: String) -> Node3D:
	var actor: Node3D
	if Installed.enabled:
		actor = Registry.create(body)
	else:
		var renderer := load(Batch.Destination + Renderers[body]) as GDScript
		actor = renderer.new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func exercise(game: Node, body: int, base: Dictionary, installed: bool) -> Dictionary:
	var row := Registry.entry(body) if installed else row_for(body, base)
	assert(row.enhanced_source_action_groups == modes_for(body))
	var clips := Batch.Bomber if body == 182 else Batch.Lord
	var report := {"poses": 0, "falls": 0, "bomb_origins": 0, "club_ground": INF, "club_grip_error": 0.0, "gap": INF, "fall_gap": INF, "jump": 0.0,
		"routes": 0, "classic": 0, "hashes": {}}
	for slope: Vector3 in Slopes:
		var floor := await create_floor(slope)
		for treatment: String in row.assets:
			var actor := create_actor(body, row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			var skins := visible_skin(actor)
			if slope == Vector3.ZERO:
				Batch.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
				var counts := check_routes(avatar, game, body, modes_for(body))
				report.routes += counts.x
				report.classic += counts.y
				report.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
			for group: int in Cases:
				var code: Array = Cases[group]
				var packet := decode(game, body, code[0], code[1])
				var clip: String = clips[group]
				start_action(avatar, packet, clip)
				for sample in 31:
					seek(actor, sample / 30.0)
					var gap := minimum_gap(actor, floor, skins)
					assert(gap >= .0016, "%d %s %s at %d has floor gap %.6f" % [body, treatment, clip, sample, gap])
					report.gap = minf(report.gap, gap)
					report.poses += 1
					if body == 83:
						assert(actor.club.visible)
						var grip_error: float = actor.club.global_position.distance_to(landmark(actor, "cp_grasp_rhand"))
						report.club_grip_error = maxf(report.club_grip_error, grip_error)
						var club_gap := club_clearance(actor.club, floor)
						assert(grip_error < .001 and club_gap >= .002)
						report.club_ground = minf(report.club_ground, club_gap)
				for phase: float in [.15, .63]:
					start_action(avatar, packet, clip)
					seek(actor, phase)
					var summary := finish_fall(actor, floor, row)
					report.jump = maxf(report.jump, summary.jump)
					report.fall_gap = minf(report.fall_gap, summary.gap)
					report.falls += 1
			if body == 182 and slope == Vector3.ZERO:
				check_bomb_palm(avatar, game)
				report.bomb_origins += 1
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	print("ORC BOMBER AND OGRE LORD RUNTIME ", body, " ", report)
	return report


func visible_skin(actor: Node3D) -> Array[Dictionary]:
	var mesh := actor.model.find_child("Body", true, false) as MeshInstance3D
	return [Ground.skin_points(mesh, actor.skeleton)]


func club_clearance(club: MeshInstance3D, floor: StaticBody3D) -> float:
	var vertices: PackedVector3Array = club.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var normal := floor.global_basis.y.normalized()
	var minimum := INF
	for vertex: Vector3 in vertices:
		minimum = minf(minimum, normal.dot(club.to_global(vertex) - floor.global_position))
	return minimum


func check_bomb_palm(avatar: Avatar, game: Node) -> void:
	var actor := avatar.horse_visual
	start_action(avatar, decode(game, 182, 5, 1), Batch.Bomber[27])
	seek(actor, .40)
	var origin := landmark(actor, "cp_grasp_rhand")
	var expected := {"kind": "moving", "graphic": 0x1c19, "speed": 1, "duration": 0, "explodes": true}
	assert(actor.begin_bomb_effect(expected.merged({"tile": 12, "explode_effect": 6014})) == null)
	assert(actor.current_clip == Batch.Bomber[27])
	var release: Variant = actor.begin_bomb_effect(expected.merged({"tile": 9502, "explode_effect": 6014}))
	assert(release is Vector3 and release.distance_to(origin) < .001 and actor.current_clip == "BombFollowThrough")


func finish_fall(source: Node3D, floor: StaticBody3D, row: Dictionary) -> Dictionary:
	var body: int = source.native_body
	var fallen := create_actor(body, row, source.treatment)
	fallen.global_transform = source.global_transform.rotated(Vector3.UP, -.31)
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	assert(fallen.begin_death_from(source) > 0.0 and fallen.current_clip == "Death")
	var joints := ["bip01 head", "cp_grasp_rhand", "bip01 r foot"]
	var jump := 0.0
	for joint: String in joints:
		jump = maxf(jump, landmark(source, joint).distance_to(landmark(fallen, joint)))
	assert(jump < .002, "%d %s handoff displaced %.6f m" % [body, source.current_clip, jump])
	var gap := INF
	var skins := visible_skin(fallen)
	for sample in 31:
		seek(fallen, sample / 30.0)
		gap = minf(gap, minimum_gap(fallen, floor, skins))
	assert(gap >= .0016, "%s fall has gap %.6f" % [source.current_clip, gap])
	if body == 83:
		assert(not fallen.club.visible)
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty())
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == 0x8035 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	assert(corpse.find_child("OgreLordBoneClub", true, false) == null)
	corpse.free()
	fallen.free()
	return {"jump": jump, "gap": gap}

