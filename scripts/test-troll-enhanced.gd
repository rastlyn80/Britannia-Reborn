# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-troll-weapon-trial.gd"

const Body := 54
const Candidate := "res://../work/creatures/native-form-audit/enhanced-source-gaps/amou/troll-%s.scn"
const Profile := preload("res://Presentation/EnhancedCreatureActions.gd")
const Installed := preload("res://Presentation/EnhancedCreatureProfile.gd")
const Classic := preload("res://Presentation/NativeMobileActions.gd")
const GestureGround := preload("res://Presentation/ArchiveGestureGround.gd")
const Modes := {
	"0": {"5": ["TrollWatch", "TrollRaiseAxe"], "8": ["TrollAlert"],
		"11": ["TrollOverheadChop", "TrollOverheadChop", "TrollOverheadChop"], "15": ["TrollRise"]},
	"1": {"5": ["TrollWatch"]},
}
const Slopes := [Vector3.ZERO, Vector3(.14, 0.0, 0.0), Vector3(-.14, 0.0, 0.0),
	Vector3(0.0, 0.0, .14), Vector3(0.0, 0.0, -.14)]
const Serial := 0x875
const Prop := "EnhancedAxe"
const Fitted := ["TrollWatch", "TrollRaiseAxe", "TrollAlert", "TrollOverheadChop", "TrollRise"]

class RouteAvatar extends Node3D:
	var horse_visual: Node3D
	func receive_native_action(request: Dictionary) -> bool:
		return horse_visual.receive_action(request)

func _initialize() -> void:
	create_timer(100.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var base := Registry.entry(Body)
	var unarmed := Registry.create(Body)
	root.add_child(unarmed)
	unarmed.apply_identity(Body, 0)
	assert(unarmed.find_child(Prop, true, false) == null)
	unarmed.free()

	var installed := "--installed" in OS.get_cmdline_user_args()
	if installed:
		assert(Installed.enable())
	var trial := Registry.entry(Body) if installed else base.duplicate(true)
	if not installed:
		trial.enhanced_source_action_groups = Modes
		trial.archive_grounded_gestures = Fitted
		for treatment: String in trial.assets:
			trial.assets[treatment] = Candidate % treatment
	assert(trial.enhanced_source_action_groups == Modes and trial.archive_grounded_gestures == Fitted)
	Registry.entries[Body] = trial
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[Serial] = {"serial": Serial, "body": Body, "hue": 0x8035}

	var selections := 0
	var compatibility := 0
	var positions := 0
	var gap := Vector2(INF, INF)
	var hashes := {}
	for tilt: Vector3 in Slopes:
		var floor := await terrain(tilt)
		for treatment: String in trial.assets:
			var actor := Registry.create(Body)
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(Body, 0x8035)
			actor.set_process(false)
			actor.set_physics_process(false)
			var ground_gesture: RefCounted
			if installed:
				ground_gesture = actor.gesture_ground
			else:
				ground_gesture = GestureGround.new()
				ground_gesture.bind(actor)
			var avatar := RouteAvatar.new()
			avatar.horse_visual = actor
			var prop := actor.find_child(Prop, true, false) as MeshInstance3D
			assert(prop != null)
			if tilt == Vector3.ZERO:
				hashes[treatment] = FileAccess.get_sha256(trial.assets[treatment])
				check_prior_keys(actor.animator, Registry.asset_path(base, treatment))
				var checked := check_routes(avatar, game)
				selections += checked.x
				compatibility += checked.y
			for request: Array in [[5, 0], [5, 1], [8, 0], [11, 0], [15, 0]]:
				var packet := decode(game, request[0], request[1])
				var pair := measure_action(avatar, floor, prop, packet, ground_gesture)
				gap = gap.min(pair)
				positions += 31
			actor.free()
			avatar.free()
		floor.free()
		await physics_frame
	print("TROLL ENHANCED TERRAIN: ", positions, " poses, min skin / axe ", gap)
	assert(gap.x > .0004 and gap.y > .25)
	for hue in [0, 53, 0x8035]:
		check_corpse(Body, hue, Prop)
	for tilt: Vector3 in Slopes:
		var axis := Vector3.RIGHT if is_zero_approx(tilt.z) else Vector3.BACK
		await check_handoff(Body, Prop, axis, tilt.x + tilt.z)
	Registry.entries[Body] = base
	game.free()
	assert(selections == 96 and compatibility == 72 and positions == 2325)
	if not installed:
		var file := FileAccess.open((Candidate % "modern").get_base_dir() + "/troll-enhanced-candidate.json", FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"routes": selections, "classic_comparisons": compatibility,
			"terrain_poses": positions, "skin_gap": gap.x, "axe_gap": gap.y, "corpse_hues": 3,
			"collapse_poses": 205, "scene_sha256": hashes,
			"test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	print("TROLL ENHANCED: ", selections, " selections, ", compatibility, " Classic comparisons")
	quit()

func check_routes(avatar: RouteAvatar, game: Node) -> Vector2i:
	var checked := Vector2i.ZERO
	for flags: int in [0, 0x40]:
		for type: int in [5, 8, 11, 15]:
			var choices: Array = Modes["1" if flags == 0 else "0"].get(str(type), Modes["0"][str(type)])
			for variation: int in [0, 1, 2, 127]:
				assert(Profile.dispatch(avatar, decode(game, type, variation), true, flags))
				assert(avatar.horse_visual.current_clip == choices[variation % choices.size()])
				checked.x += 1
			for variation: int in [0, 128, 255]:
				var packet := decode(game, type, variation)
				var accepted := Classic.dispatch(avatar, packet)
				var prior: String = avatar.horse_visual.current_clip
				assert(Profile.dispatch(avatar, packet, variation > 0, flags) == accepted)
				assert(avatar.horse_visual.current_clip == prior)
				checked.y += 1
	return checked

func terrain(tilt: Vector3) -> StaticBody3D:
	var result := StaticBody3D.new()
	result.rotation = tilt
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(12.0, .10, 12.0)
	collider.shape = shape
	collider.position.y = -.05
	result.add_child(collider)
	root.add_child(result)
	await physics_frame
	await physics_frame
	return result

func measure_action(avatar: RouteAvatar, floor: StaticBody3D, prop: MeshInstance3D, packet: Dictionary,
		ground_gesture: RefCounted) -> Vector2:
	var actor := avatar.horse_visual
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	var joint := prop.skin.get_bind_bone(0)
	var wrist := rig.get_bone_parent(joint)
	assert(rig.get_bone_name(wrist) == "cp_grasp_rhand")
	var skin := Ground.skin_points(actor.model.find_children("*", "MeshInstance3D", true, false)[0], rig)
	var axe := Ground.skin_points(prop, rig)
	var initial: Transform3D = actor.global_transform
	var normal := floor.global_basis.y
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.stop()
	player.play("Idle", 0.0)
	player.advance(0.0)
	assert(Profile.dispatch(avatar, packet, true, 0x40))
	player.advance(.13)
	var lowest := Vector2(INF, INF)
	for i in 31:
		player.seek(player.current_animation_length * float(i) / 30.0, true)
		ground_gesture.release(actor)
		actor._physics_process(1.0 / 60.0)
		actor.contact._process_modification_with_delta(1.0 / 60.0)
		rig.force_update_all_bone_transforms()
		actor.contact.modification_processed.emit()
		var socket := rig.get_bone_global_pose(wrist) * rig.get_bone_rest(joint).origin
		assert(socket.distance_to(rig.get_bone_global_pose(joint).origin) < .0001)
		assert(actor.global_transform.is_equal_approx(initial))
		var base := Ground.minimum_plane_gap(skin, rig, rig.global_transform, floor.position, normal)
		var weapon := Ground.minimum_plane_gap(axe, rig, rig.global_transform, floor.position, normal)
		lowest = lowest.min(Vector2(base, weapon))
	return lowest

func check_prior_keys(player: AnimationPlayer, source: String) -> void:
	var model := (load(source) as PackedScene).instantiate()
	var prior := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for name in prior.get_animation_list():
		var before := prior.get_animation(name)
		var after := player.get_animation(name)
		assert(before.length == after.length and before.get_track_count() + 1 == after.get_track_count())
		assert(after.track_get_path(after.get_track_count() - 1).get_subname(0) == "troll enhanced axe")
		for index in before.get_track_count():
			assert(before.track_get_path(index) == after.track_get_path(index))
			assert(before.get("tracks/%d/keys" % index) == after.get("tracks/%d/keys" % index))
	model.free()

func decode(game: Node, type: int, variation: int) -> Dictionary:
	var packet := PackedByteArray([0xe2])
	packet.append_array(Wire.uint_be(Serial, 4))
	packet.append_array(PackedByteArray([0, type, 0, 0, variation]))
	game._handle(packet)
	return game.last_mobile_actions[Serial]
