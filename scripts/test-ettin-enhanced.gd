# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const VisualPath := "res://Presentation/SourceEnhancedEttinVisual.gd"
const Visual := preload(VisualPath)
const Dispatch := preload("res://Presentation/EnhancedCreatureActions.gd")
const Classic := preload("res://Presentation/NativeMobileActions.gd")
const Installed := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const Snapshot := preload("res://Presentation/CreatureCorpseSnapshot.gd")
const Body := 18
const Serial := 0x651
const Path := "res://../work/creatures/native-form-audit/enhanced-source-gaps/bird-ettin/"
const Treatments := ["original", "rounded", "modern"]
const Slopes := [Vector3.ZERO, Vector3(.14, 0, 0), Vector3(-.14, 0, 0), Vector3(0, 0, .14), Vector3(0, 0, -.14)]
const Modes := {"0": {"8": ["EttinAlert"], "15": ["EttinRise"]}, "1": {}}

class Avatar extends Node3D:
	var horse_visual: Node3D
	func receive_native_action(request: Dictionary) -> bool:
		return horse_visual.receive_action(request)

var actions := 0
var comparisons := 0
var terrain_poses := 0
var fall_poses := 0
var handoffs := 0
var lowest_action := INF
var lowest_fall := INF
var maximum_handoff_gap := 0.0
var maximum_hammer_lift := 0.0

func _initialize() -> void:
	create_timer(150.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var base := Registry.entry(Body)
	var vanilla := Registry.create(Body)
	root.add_child(vanilla)
	assert(vanilla.find_child("EnhancedHammer", true, false) == null)
	vanilla.free()
	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	var row := Registry.entry(Body) if installed else base.duplicate(true)
	if not installed:
		row.enhanced_source_action_groups = Modes
		for treatment: String in Treatments:
			row.assets[treatment] = Path + "ettin-%s.scn" % treatment
	assert(row.enhanced_source_action_groups == Modes)
	for treatment: String in Treatments:
		check_source(base.assets[treatment], row.assets[treatment])
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[Serial] = {"serial": Serial, "body": Body, "hue": 0x8035}
	for tilt: Vector3 in Slopes:
		var floor := await make_floor(tilt)
		for treatment: String in Treatments:
			var actor := create_actor(row, treatment)
			var avatar := Avatar.new()
			avatar.horse_visual = actor
			if tilt == Vector3.ZERO:
				check_routes(avatar, game)
			for kind in [8, 15]:
				assert(Dispatch.dispatch(avatar, decode_new(game, kind), true, 0x40))
				assert(actor.current_clip == Modes["0"][str(kind)][0])
				var player: AnimationPlayer = actor.animator
				player.advance(.13)
				for frame in 31:
					player.seek(player.current_animation_length * frame / 30.0, true)
					for i in 15:
						actor._physics_process(1.0 / 60.0)
					actor.contact._process_modification_with_delta(1.0 / 60.0)
					actor.contact.modification_processed.emit()
					var gap := measure(actor, floor.position, floor.basis.y.normalized())
					lowest_action = minf(lowest_action, gap)
					terrain_poses += 1
			avatar.free()
			actor.free()
			for direction: int in [2, 3]:
				test_fall(game, row, treatment, floor, direction)
		floor.free()
		await physics_frame
	for hue: int in [0, 53, 0x8035]:
		Registry.entries[Body] = row
		var cadaver := Corpses.build(Body, hue)
		assert(cadaver != null and cadaver.get_meta("corpse_body") == Body and cadaver.get_meta("native_hue") == hue)
		assert(cadaver.get_node_or_null("EnhancedHammer") != null and cadaver.get_meta("static_cadaver"))
		cadaver.free()
		Registry.entries[Body] = base
	game.free()
	print("ETTIN ENHANCED: ", actions, " selections, ", comparisons, " Classic comparisons, ", terrain_poses, " gesture poses, ", fall_poses,
		" fall poses, ", handoffs, " handoffs, action/fall gaps ", lowest_action, "/", lowest_fall,
		", handoff drift ", maximum_handoff_gap, ", max extra lift ", maximum_hammer_lift)
	assert(actions == 48 and comparisons == 36 and terrain_poses == 930 and fall_poses == 1230 and handoffs == 30)
	assert(lowest_action > .001 and lowest_fall > .001 and maximum_handoff_gap < .025 and maximum_hammer_lift < .005)
	if not installed:
		var hashes := {}
		for treatment: String in Treatments:
			hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
		var file := FileAccess.open(Path + "ettin-enhanced-candidate.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"routes": actions, "classic_comparisons": comparisons,
			"terrain_poses": terrain_poses, "fall_poses": fall_poses, "handoffs": handoffs, "corpse_hues": 3,
			"min_action_gap": lowest_action, "min_fall_gap": lowest_fall, "max_handoff_gap": maximum_handoff_gap,
			"max_hammer_lift": maximum_hammer_lift, "scene_sha256": hashes,
			"renderer_sha256": FileAccess.get_sha256(VisualPath),
			"test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	quit()

func check_routes(avatar: Avatar, game: Node) -> void:
	var actor := avatar.horse_visual
	for flags: int in [0, 64]:
		for kind: int in [8, 15]:
			for variant: int in [0, 1, 2, 127]:
				assert(Dispatch.dispatch(avatar, decode_new(game, kind, variant), true, flags))
				assert(actor.current_clip == Modes["0"][str(kind)][0])
				actions += 1
			for variant: int in [0, 128, 255]:
				var packet := decode_new(game, kind, variant)
				var accepted := Classic.dispatch(avatar, packet)
				var prior: String = actor.current_clip
				assert(Dispatch.dispatch(avatar, packet, variant > 0, flags) == accepted and actor.current_clip == prior)
				comparisons += 1

func create_actor(row: Dictionary, treatment: String) -> Node3D:
	var actor := Registry.create(Body) if "--installed" in OS.get_cmdline_user_args() else Visual.new()
	actor.entry = row
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(Body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor

func make_floor(tilt: Vector3) -> StaticBody3D:
	var floor := StaticBody3D.new()
	floor.rotation = tilt
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12.0, .10, 12.0)
	collider.shape = box
	collider.position.y = -.05
	floor.add_child(collider)
	root.add_child(floor)
	await physics_frame
	await physics_frame
	return floor

func measure(actor: Node3D, origin: Vector3, normal: Vector3) -> float:
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	var weapon := rig.find_bone("ettin enhanced hammer")
	var socket := rig.get_bone_global_pose(rig.get_bone_parent(weapon))
	assert(rig.get_bone_global_pose(weapon).origin.distance_to(socket * rig.get_bone_rest(weapon).origin) < .0001)
	assert(actor.global_position.is_zero_approx())
	var body := Ground.minimum_plane_gap(actor.body_skin, rig, rig.global_transform, origin, normal)
	var hammer := Ground.minimum_plane_gap(actor.hammer_skin, rig, rig.global_transform, origin, normal)
	return minf(body, hammer)

func test_fall(game: Node, row: Dictionary, treatment: String, floor: StaticBody3D, direction: int) -> void:
	var actor := create_actor(row, treatment)
	var expected := "Death2" if direction == 2 else "Death"
	assert(actor.receive_action(decode_classic(game, direction)) and actor.current_clip == expected)
	var player: AnimationPlayer = actor.animator
	player.advance(.13)
	var duration := player.current_animation_length
	var handoff_frame := 20
	var fall_gap := INF
	var lift := 0.0
	for i in 41:
		player.seek(duration * i / 40.0, true)
		var gap := measure(actor, floor.position, floor.basis.y.normalized())
		if gap < fall_gap:
			fall_gap = gap
			if gap < 0.0:
				print("ETTIN FLOOR DIAGNOSTIC ", [expected, treatment, floor.rotation, i, gap,
					actor.fall.plane.position, actor.fall.plane.normal, actor.hammer_lift])
		lift = maxf(lift, actor.hammer_lift)
		lowest_fall = minf(lowest_fall, gap)
		maximum_hammer_lift = maxf(maximum_hammer_lift, actor.hammer_lift)
		fall_poses += 1
		if i == handoff_frame:
			witness_handoff(actor, row, treatment, expected, floor)
	if lift > .10:
		print("ETTIN LIFT DIAGNOSTIC ", [expected, treatment, floor.rotation, lift])
	actor.free()

func witness_handoff(actor: Node3D, row: Dictionary, treatment: String, clip: String, floor: StaticBody3D) -> void:
	var visual := create_actor(row, treatment)
	visual.model.transform = actor.model.transform
	visual.dead = true
	var before := grip_at(actor)
	var time: float = actor.animator.current_animation_position
	assert(visual.begin_death_from(actor) > .0 and visual.current_clip == clip)
	assert(absf(visual.animator.current_animation_position - time) < .002)
	maximum_handoff_gap = maxf(maximum_handoff_gap, before.distance_to(grip_at(visual)))
	visual.animator.seek(visual.animator.current_animation_length, true)
	var saved := Snapshot.capture(visual, visual.corpse_snapshot_floor())
	assert(not saved.is_empty())
	var corpse: Node3D = saved.scene.instantiate()
	root.add_child(corpse)
	corpse.global_transform = saved.placement
	assert(corpse.get_meta("death_clip") == clip and corpse.get_meta("native_hue") == 0x8035)
	assert(corpse.find_children("*", "Skeleton3D", true, false).is_empty())
	var normal := floor.basis.y.normalized()
	for part: MeshInstance3D in corpse.find_children("*", "MeshInstance3D", true, false):
		for surface in part.mesh.get_surface_count():
			var points: PackedVector3Array = part.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point: Vector3 in points:
				assert((part.to_global(point) - floor.position).dot(normal) >= .001)
	corpse.free()
	visual.free()
	handoffs += 1

func grip_at(actor: Node3D) -> Vector3:
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone("cp_grasp_rhand")).origin)

func decode_new(game: Node, kind: int, variation := 0) -> Dictionary:
	var bytes := PackedByteArray([0xe2])
	bytes.append_array(Wire.uint_be(Serial, 4))
	bytes.append_array(PackedByteArray([0, kind, 0, 0, variation]))
	game._handle(bytes)
	return game.last_mobile_actions[Serial]

func decode_classic(game: Node, direction: int) -> Dictionary:
	var bytes := PackedByteArray([0x6e])
	bytes.append_array(Wire.uint_be(Serial, 4))
	bytes.append_array(Wire.uint_be(direction, 2))
	bytes.append_array(PackedByteArray([0, 8, 0, 1, 1, 0, 0]))
	game._handle(bytes)
	return game.last_mobile_actions[Serial]

func check_source(source: String, candidate: String) -> void:
	var original := (load(source) as PackedScene).instantiate()
	var fitted := (load(candidate) as PackedScene).instantiate()
	var old := original.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var newer := fitted.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for clip: String in old.get_animation_list():
		var before := old.get_animation(clip)
		var after := newer.get_animation("RecoveredDeath" if clip == "Death" else clip)
		assert(before.length == after.length and before.get_track_count() + (0 if clip == "Death" else 1) == after.get_track_count())
		for track in before.get_track_count():
			assert(before.track_get_path(track) == after.track_get_path(track))
			assert(before.get("tracks/%d/keys" % track) == after.get("tracks/%d/keys" % track))
			if clip == "Death":
				var armed := newer.get_animation("Death")
				var label := str(before.track_get_path(track).get_subname(0)) if before.track_get_path(track).get_subname_count() else ""
				var armed_arm := label in ["bip01 r upperarm", "bip01 r forearm", "bip01 r hand"]
				assert(armed.length == before.length and before.track_get_path(track) == armed.track_get_path(track))
				if not armed_arm or before.track_get_type(track) != Animation.TYPE_ROTATION_3D:
					assert(before.get("tracks/%d/keys" % track) == armed.get("tracks/%d/keys" % track))
	original.free()
	fitted.free()
