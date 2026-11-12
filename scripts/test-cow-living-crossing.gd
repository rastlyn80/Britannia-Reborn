# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-bull-living-terrain.gd"

const Wire := preload("res://Network/LoginProtocol.gd")
const Game := preload("res://Network/GameSession.gd")
const Tick := 1.0 / 60.0
const Mobile := 0x2010

var outcomes := {}
var tips := 0
var tip_frames := 0


func run() -> void:
	if enhanced:
		assert(Cattle.enable())
		Registry.enhanced_bovine_actions = true
	var lower := board(Vector3(4, .2, 8))
	lower.position = Vector3(-2, -.1, 0)
	var upper := board(Vector3(4, .2, 8))
	upper.position = Vector3(2, Height - .1, 0)
	await physics_frame
	await physics_frame
	for body: int in [216, 231]:
		var row := {}
		for heading: float in [PI * .5, PI * 1.5]:
			for clip: String in ["Walk", "Run"]:
				for phase: float in [0.0, .34, .68]:
					cross(body, heading, clip, phase, row)
			for x: float in [-.36, -.14, .14, .36]:
				tip(body, heading, x, row)
		assert(row.moving_penetration.value < -.001 and row.tip_penetration.value < -.001
			and row.recovery_penetration.value < -.001 and row.lift_change.value < .085)
		outcomes[body] = row
		print("COW CROSSING ", body, ": ", JSON.stringify(row))
	var label := "enhanced" if enhanced else "classic"
	print("COW CROSSING: ", poses, " moving poses, ", tips, " living tips, ", tip_frames, " tip and recovery poses, ", label)
	quit(0 if poses == 1500 and tips == 16 and tip_frames == 1312 else 1)


func make_cow(body: int, heading: float) -> Node3D:
	var actor := Registry.create(body)
	actor.rotation.y = heading
	root.add_child(actor)
	actor.apply_identity(body, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	return actor


func support(actor: Node3D) -> void:
	actor._physics_process(Tick)
	actor.contact._process_modification_with_delta(Tick)
	actor.contact.modification_processed.emit()
	actor.skeleton.force_update_all_bone_transforms()


func cross(body: int, heading: float, clip: String, start: float, row: Dictionary) -> void:
	var actor := make_cow(body, heading)
	var rig: Skeleton3D = actor.skeleton
	var skin := Ground.skin_points(actor.contact.surface, rig)
	var player: AnimationPlayer = actor.animator
	var span := 2.5
	var speed := 1.7 if clip == "Walk" else 4.5
	var count := int(ceil(span / (speed * Tick)))
	var direction := 1.0 if heading < PI else -1.0
	var previous_lift := 0.0
	var previous_phase := 0.0
	var previous_hoof := Vector3.ZERO
	var tracked := actor.find_source_bone("l foot") as int
	assert(tracked >= 0)
	actor.current_clip = clip
	player.play(clip, 0.0)
	player.advance(0.0)
	for index in count + 1:
		var x := direction * lerpf(-span / 2.0, span / 2.0, index / float(count))
		var anchor := Vector3(x, Height * clampf(x + .5, 0.0, 1.0), 0)
		actor.position = anchor
		var phase := fposmod(start + index * Tick / player.current_animation_length, 1.0)
		player.seek(player.current_animation_length * phase, true)
		support(actor)
		assert(actor.position == anchor and actor.native_hue == 0x8035 and not actor.dead)
		var details := {"clip": clip, "x": x, "phase": phase, "heading": heading}
		var gap := step_gap(skin, rig)
		assert(is_finite(gap))
		maximum(row, "moving_penetration", -gap, details)
		var lift: float = actor.ground.lift
		var hoof := rig.to_global(rig.get_bone_global_pose(tracked).origin) - anchor
		maximum(row, "moving_lift", lift, details)
		if index > 0:
			maximum(row, "lift_change", absf(previous_lift - lift), details)
			if phase < previous_phase:
				maximum(row, "hoof_seam", hoof.distance_to(previous_hoof), details)
		previous_lift = lift
		previous_phase = phase
		previous_hoof = hoof
		poses += 1
	actor.free()


func tip(body: int, heading: float, x: float, row: Dictionary) -> void:
	var actor := make_cow(body, heading)
	var rig: Skeleton3D = actor.skeleton
	var skin := Ground.skin_points(actor.contact.surface, rig)
	var player: AnimationPlayer = actor.animator
	actor.position = Vector3(x, Height if x > 0.0 else 0.0, 0.0)
	var anchor := actor.position
	actor.set_native_combat_flags(0)
	actor.play_gait(false, 0.0)
	player.advance(0.0)
	if x < 0.0:
		for iteration in 20:
			support(actor)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[Mobile] = {"serial": Mobile, "body": body, "hue": 0x8035}
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(Mobile, 4))
	packet.append_array(PackedByteArray([0, 8, 0, 0, 0, 3, 1, 0, 0]))
	game._handle(packet)
	assert(actor.receive_action(game.last_mobile_actions[Mobile]))
	assert(actor.recovering_tip and not actor.dead and actor.current_clip == "LieDown")
	player.advance(0.0)
	var length := player.current_animation_length
	for index in 41:
		player.seek(length * index / 40.0, true)
		support(actor)
		assert(actor.position == anchor and not actor.dead and actor.recovering_tip)
		maximum(row, "tip_penetration", -step_gap(skin, rig), {"x": x, "heading": heading, "phase": index / 40.0})
		tip_frames += 1
	actor._process(actor.action_remaining + .01)
	var standing := Cattle.Grazing if enhanced else "Idle"
	assert(not actor.dead and not actor.recovering_tip and actor.current_clip == standing)
	for index in 41:
		player.advance(Tick)
		support(actor)
		assert(actor.position == anchor and not actor.dead and actor.current_clip == standing)
		maximum(row, "recovery_penetration", -step_gap(skin, rig), {"x": x, "heading": heading, "frame": index})
		tip_frames += 1
	actor.play_gait(true, 2.0)
	assert(actor.current_clip == "Walk" and not actor.dead)
	tips += 1
	actor.free()
	game.free()


func maximum(row: Dictionary, label: String, value: float, details: Dictionary) -> void:
	if value > float(row.get(label, {}).get("value", -INF)):
		row[label] = details.merged({"value": value})
