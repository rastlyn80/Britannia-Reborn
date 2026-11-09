# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Keys := preload("res://../scripts/test-quadruped-actions.gd")
const Game := preload("res://Network/GameSession.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Trial := "res://local-art/creatures/animated_weapon/animated-weapon-uop.scn"
const Actions := {"2": "UopHalberdRecoil", "8": "UopHalberdSpin", "11": "UopHalberdHover",
	"14": "UopHalberdHover", "15": "UopHalberdRise"}
const FittedClips := ["UopHalberdHover", "UopHalberdRecoil", "UopHalberdRise", "UopHalberdReadyHover", "UopHalberdSpin"]

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var row := Registry.entry(692).duplicate(true)
	var source: String = row.get("uop_motion_base_asset", Registry.asset_path(row))
	if "--active" in OS.get_cmdline_user_args():
		assert(row.has("uop_motion_native_sha256") and Registry.asset_path(row) == Trial)
		assert(Actions.keys().all(func(kind: String) -> bool: return row.new_action_categories[kind] == Actions[kind]))
	else:
		for treatment: String in row.assets:
			row.assets[treatment] = Trial
		row.new_action_categories = row.get("new_action_categories", {}).merged(Actions, true)
		Registry.entries[692] = row
	var visual := Registry.create(692)
	root.add_child(visual)
	visual.apply_identity(692, 0x8035)
	visual.set_process(false)
	visual.set_physics_process(false)
	Keys.check_earlier_keys(visual.animator, source)
	var mesh := visual.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var rig: Skeleton3D = visual.skeleton
	var skin := Ground.skin_points(mesh, rig)
	var player: AnimationPlayer = visual.animator
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[692] = {"serial": 692, "body": 692, "hue": 0x8035}
	var lowest := INF
	var action_count := 0
	var poses := 0
	for action: String in Actions:
		for mode in range(2):
			var packet := PackedByteArray([0xe2])
			packet.append_array(Wire.uint_be(692, 4))
			packet.append_array(PackedByteArray([0, int(action), 0, 0, mode]))
			game._handle(packet)
			assert(visual.receive_action(game.last_mobile_actions[692]))
			assert(visual.current_clip == Actions[action] and not visual.dead)
			assert(visual.get_meta("native_action").variation == mode)
			action_count += 1
	for clip: String in FittedClips:
		player.stop()
		player.play(clip, 0.0)
		var floor_gap := INF
		for index in range(121):
			player.seek(float(index) / 120.0 * player.current_animation_length, true)
			rig.force_update_all_bone_transforms()
			floor_gap = minf(floor_gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
			poses += 1
		print("HALBERD CLIP ", clip, " flat minimum ", floor_gap)
		lowest = minf(lowest, floor_gap)
	assert(lowest > 0.003)
	print("HALBERD ACTIONS: ", action_count, " decoded packet actions, ", poses, " poses, minimum raw clearance ", lowest)
	game.free()
	visual.free()
	var total := 0
	var minimum := INF
	for tilt: Vector3 in [Vector3.ZERO, Vector3(0.14, 0.0, -0.10), Vector3(-0.12, 0.0, 0.13)]:
		var plane := await finite_plane(tilt)
		var result := sample_terrain(plane)
		total += int(result.x)
		minimum = minf(minimum, result.y)
		plane.free()
		await physics_frame
	assert(total == 915)
	print("HALBERD TERRAIN: ", total, " fitted poses across three finite planes, minimum ", minimum)
	quit()

func finite_plane(tilt: Vector3) -> StaticBody3D:
	var plane := StaticBody3D.new()
	root.add_child(plane)
	plane.rotation = tilt
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 0.10, 8.0)
	var collider := CollisionShape3D.new()
	collider.shape = box
	collider.position.y = -0.05
	plane.add_child(collider)
	await physics_frame
	await physics_frame
	return plane

func sample_terrain(plane: StaticBody3D) -> Vector2:
	var actor := Registry.create(692)
	actor.treatment = "original"
	root.add_child(actor)
	actor.apply_identity(692, 0)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var mesh := actor.model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var minimum := INF
	var tested := 0
	var anchor := actor.global_transform
	for clip: String in FittedClips:
		player.stop()
		actor.current_clip = clip
		player.play(clip, 0.0)
		player.advance(0.0)
		for frame in 61:
			player.seek(player.current_animation_length * frame / 60.0, true)
			actor._physics_process(1.0 / 60.0)
			actor.contact._process_modification_with_delta(1.0 / 60.0)
			rig.force_update_all_bone_transforms()
			actor.contact.modification_processed.emit()
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform,
				plane.global_position, plane.global_basis.y.normalized())
			assert(is_finite(gap) and gap > 0.0015 and actor.global_transform == anchor,
				str([clip, frame, gap, plane.rotation]))
			minimum = minf(minimum, gap)
			tested += 1
	actor.free()
	return Vector2(tested, minimum)
