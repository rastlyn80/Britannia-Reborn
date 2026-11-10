# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-field-enhanced.gd"

const Stage := "res://../work/creatures/native-form-audit/enhanced-source-gaps/zombie-wraith/"
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")
const Spectral := preload("res://Presentation/WraithSpectralSurface.gdshader")
const Rise := "ZombieGraveRise"
const Gather := "WraithReconstitute"
const Scatter := "WraithScatterFall"
const Modes := {
	3: {"0": {"5": ["ZombieSlumpedWatch", "ZombieTwistedGuard"], "8": ["ZombieArmsUp"],
		"11": ["ZombieLurchSwipe", "ZombieLurchSwipe", "ZombieLurchSwipe"],
		"14": ["ZombieQuietSway"], "15": [Rise]}, "1": {"5": ["ZombieSlumpedWatch"]}},
	26: {"0": {"5": ["WraithVeilInspect", "WraithVeilDive"], "8": ["WraithWindborneReach"],
		"11": ["WraithSurge", "WraithSurge", "WraithSurge"], "15": [Gather]}, "1": {"5": ["WraithVeilInspect"]}},
}
const Trials := {3: "SourceEnhancedZombieVisual.gd", 26: "SourceEnhancedWraithVisual.gd"}
var using_installed := false

func run() -> void:
	var bases := {3: Registry.entry(3), 26: Registry.entry(26)}
	using_installed = "--installed" in OS.get_cmdline_user_args()
	if using_installed:
		assert(Installed.enable())
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var reports := {}
	for body: int in Modes:
		reports[str(body)] = await review(game, body, bases[body])
		assert(not reports[str(body)].is_empty())
	game.free()
	if not using_installed:
		var output := FileAccess.open(Stage + "terrain-receipt.json", FileAccess.WRITE)
		assert(output != null)
		output.store_string(JSON.stringify({"bodies": reports, "test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		output.close()
	quit()

func review(game: Node, body: int, base: Dictionary) -> Dictionary:
	var row := Registry.entry(body) if using_installed else base.duplicate(true)
	var options: Dictionary = Modes[body]
	var samples := {}
	for kind: String in options["0"]:
		for variation in options["0"][kind].size():
			var clip: String = options["0"][kind][variation]
			if not samples.has(clip):
				samples[clip] = [int(kind), variation]
	if not using_installed:
		row.enhanced_source_action_groups = options
		row.archive_grounded_gestures = samples.keys() if body == 3 else []
		row.presentation_script = "res://Presentation/TrialZombieVisual.gd" if body == 3 else "res://Presentation/TrialWraithVisual.gd"
		for treatment: String in row.assets:
			row.assets[treatment] = Stage + ("26-reconstitute-%s.scn" % treatment if body == 26 else "3-%s.scn" % treatment)
		Registry.entries[body] = row
	game.entities[body] = {"serial": body, "body": body, "hue": hue_for(body)}
	var report := {"selections": 0, "classic": 0, "poses": 0, "hashes": {}, "poses_by_clip": {}, "joins": [], "falls": [], "hues": 0}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for treatment: String in row.assets:
			var actor := create_fit(body, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				Bake.verify_base_clips(actor.animator, Registry.asset_path(base, treatment))
				var counts := check_routes(avatar, game, body, options)
				report.selections += counts.x
				report.classic += counts.y
				report.hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
			for clip: String in samples:
				var selection: Array = samples[clip]
				var packet := decode(game, body, selection[0], selection[1])
				var pose := sample_motion(avatar, floor, packet, clip)
				assert(pose.has("gap"))
				report.poses += 31
				if tilt == Vector3.ZERO and treatment == "modern":
					report.poses_by_clip[clip] = pose
				if clip == Gather:
					report.joins.append(pose.join)
					assert(pose.first_pieces == 5 and pose.maximum_pieces == 6 and pose.join < .003, str(pose))
			if body == 3:
				for phase: float in [.035, .34, .68, .96]:
					report.falls.append(check_fall(avatar, floor, decode(game, body, 15, 0), treatment, phase, false))
			else:
				for phase: float in [.06, .28, .54, .78]:
					report.falls.append(check_fall(avatar, floor, decode(game, body, 15, 0), treatment, phase, phase < .60))
				report.falls.append(check_fall(avatar, floor, decode(game, body, 11, 0), treatment, .40, false))
			avatar.free()
			actor.free()
		floor.free()
		await physics_frame
	for hue: int in ([0, 0x8035, 0x455] if body == 3 else [0, 0x4001, 0x8035, 0x455]):
		var corpse := Corpses.build(body, hue)
		assert(corpse != null and corpse.get_meta("graphic_id") == 0x2006 and corpse.get_meta("corpse_body") == body,
			"Body %d hue %04X must create a static corpse" % [body, hue])
		assert(corpse.get_meta("native_hue") == hue and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		if hue == 0x4001:
			check_spectral(corpse)
		corpse.free()
		report.hues += 1
	Registry.entries[body] = base
	assert(report.selections == (120 if body == 3 else 96) and report.classic == (90 if body == 3 else 72))
	assert(report.poses == samples.size() * 465 and report.falls.size() == (60 if body == 3 else 75))
	assert(report.falls.all(func(fall: Dictionary): return fall.has("jump")))
	print("ZOMBIE/WRAITH ", body, ": ", report.selections, " decoded, ", report.poses, " terrain, ", report.falls.size(), " death handoffs")
	return report

func hue_for(body: int) -> int:
	return 0x4001 if body == 26 else 0x8035

func create_fit(body: int, treatment: String) -> Node3D:
	var actor: Node3D
	if using_installed:
		actor = Registry.create(body)
	else:
		actor = load(Stage + Trials[body]).new()
	actor.entry = Registry.entry(body)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(body, hue_for(body))
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor

func start_motion(avatar: Avatar, packet: Dictionary) -> void:
	var actor := avatar.horse_visual
	actor.animator.stop()
	actor.action_remaining = 0.0
	actor.play_gait(false, 0.0)
	actor.animator.advance(.19)
	assert(Dispatch.dispatch(avatar, packet, true, 64))
	actor.animator.advance(.13)
	actor.animator.seek(0.0, true)

func sample_motion(avatar: Avatar, floor: StaticBody3D, packet: Dictionary, clip: String) -> Dictionary:
	var actor := avatar.horse_visual
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var mesh: MeshInstance3D = actor.model.find_child("Body", true, false)
	var skin := Ground.skin_points(mesh, rig)
	start_motion(avatar, packet)
	assert(actor.current_clip == clip)
	var report := {"gap": INF, "final_gap": 0.0, "first_top": 0.0, "first_pieces": 0, "maximum_pieces": 0, "join": 0.0}
	for i in 31:
		if clip == Gather and i == 18:
			player.seek(player.current_animation_length * .5999, true)
			assert(actor.pieces.visible)
			var before: AABB = part_extent(actor, floor).bounds
			player.seek(player.current_animation_length * .6001, true)
			assert(actor.living_mesh.visible and not actor.pieces.visible)
			var after := Geometry.deformed_bounds(mesh, rig)
			report.join = maxf(before.position.distance_to(after.position), before.end.distance_to(after.end))
		player.seek(player.current_animation_length * i / 30.0, true)
		actor._physics_process(1.0 / 60.0)
		rig.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, floor.position, floor.basis.y)
		if clip == Gather and actor.pieces.visible:
			var pieces := part_extent(actor, floor)
			gap = pieces.gap
			if i == 0:
				report.first_pieces = pieces.count
			report.maximum_pieces = maxi(report.maximum_pieces, pieces.count)
		report.gap = minf(gap, report.gap)
		report.final_gap = gap
		if i == 0 and clip == Rise:
			report.first_top = Geometry.deformed_bounds(mesh, rig).end.y
	if clip == Rise:
		assert(report.gap < -1.8 and report.final_gap > .003, str(report))
	else:
		assert(report.gap >= .0019, "%s clearance %s" % [clip, report.gap])
	if clip == Gather:
		check_spectral(actor.model)
	return report

func check_fall(avatar: Avatar, floor: StaticBody3D, packet: Dictionary, treatment: String, phase: float, scattered: bool) -> Dictionary:
	var source := avatar.horse_visual
	var body := int(source.native_body)
	start_motion(avatar, packet)
	source.animator.seek(source.animator.current_animation_length * phase, true)
	source._physics_process(1.0 / 60.0)
	source.skeleton.force_update_all_bone_transforms()
	var head := source.skeleton.find_bone("bip01 head") as int
	var old_head: Vector3 = source.skeleton.to_global(source.skeleton.get_bone_global_pose(head).origin)
	var before := part_extent(source, floor) if scattered else {}
	var fallen := create_fit(body, treatment)
	fallen.global_transform = source.global_transform
	fallen.model.transform = source.model.transform
	fallen.dead = true
	fallen.contact.enabled = false
	var duration: float = fallen.begin_death_from(source)
	assert(duration > .0 and fallen.current_clip == (Scatter if scattered else "Death"))
	var rig: Skeleton3D = fallen.skeleton
	rig.force_update_all_bone_transforms()
	var jump := old_head.distance_to(rig.to_global(rig.get_bone_global_pose(head).origin))
	if scattered:
		var old_bounds: AABB = before.bounds
		var next: AABB = part_extent(fallen, floor).bounds
		jump = maxf(old_bounds.position.distance_to(next.position), old_bounds.end.distance_to(next.end))
		assert(fallen.falling_parts.size() == before.count)
	assert(jump < .002, "Body %d %s phase %.2f jumped %f" % [body, source.current_clip, phase, jump])
	var minimum := INF
	var mesh: MeshInstance3D = fallen.model.find_child("Body", true, false)
	var skin := Ground.skin_points(mesh, rig)
	for i in 31:
		if scattered:
			fallen.advance_scatter(float(i) / 30.0)
			minimum = minf(minimum, part_extent(fallen, floor).gap)
		else:
			var time := duration * float(i) / 30.0
			fallen.animator.seek(time, true)
			rig.force_update_all_bone_transforms()
			if body == 26 or time >= fallen.grave_fall.blend_length:
				minimum = minf(minimum, Ground.minimum_plane_gap(skin, rig, rig.global_transform, floor.position, floor.basis.y))
	assert(minimum >= .0019, "Body %d phase %.2f fall support %f" % [body, phase, minimum])
	var snapshot := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
	assert(not snapshot.is_empty() and snapshot.body == body)
	var corpse: Node3D = snapshot.scene.instantiate()
	assert(corpse.get_meta("native_hue") == hue_for(body))
	assert(corpse.get_child_count() == (int(before.count) if scattered else 1))
	if body == 26:
		check_spectral(corpse)
	corpse.free()
	fallen.free()
	return {"phase": phase, "scattered": scattered, "pieces": before.get("count", 0), "jump": jump, "gap": minimum}

func part_extent(actor: Node3D, floor: StaticBody3D) -> Dictionary:
	var gap := INF
	var bounds := AABB()
	var count := 0
	for part: MeshInstance3D in actor.piece_points:
		if not part.visible:
			continue
		for vertex: Vector3 in actor.piece_points[part]:
			var point := part.to_global(vertex)
			if is_inf(gap):
				bounds = AABB(point, Vector3.ZERO)
			bounds = bounds.expand(point)
			gap = minf(gap, (point - floor.position).dot(floor.basis.y))
		count += 1
	return {"gap": gap, "count": count, "bounds": bounds}

func check_spectral(model: Node3D) -> void:
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var material := part.get_active_material(0) as ShaderMaterial
		assert(material != null and material.shader == Spectral and material.get_shader_parameter("source_atlas") is Texture2D)
