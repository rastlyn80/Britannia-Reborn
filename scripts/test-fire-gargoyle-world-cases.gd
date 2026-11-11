# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Attack := preload("test-minotaur-scout-world-cases.gd")
const Projectile := preload("res://Presentation/SourceEnhancedFireBreathProjectilePresenter.gd")
const Classic := preload("res://Presentation/NativeMobileActions.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Body := 130
const Breath := "FireGargoyleFireBreath"
const Joints := ["bip01 head", "bip01 l hand", "bip01 r hand", "gargoyle r wing3"]
const Cases := [
	{"body": Body, "type": 0, "variant": 1, "clip": "FireGargoyleSwoopingClaw", "phase": .58,
		"hue": 0x8035, "joints": Joints},
	{"body": Body, "type": 14, "clip": "FireGargoyleAshSearch", "phase": .41,
		"hue": 0x455, "joints": Joints},
	{"body": Body, "type": 5, "variant": 1, "flags": 0, "clip": "FireGargoyleRest",
		"phase": .67, "hue": 0, "joints": Joints},
]
const AttackCases := [
	[0, 1, "FireGargoyleSwoopingClaw"], [1, 1, "FireGargoyleOverheadRake"], [9, 1, "FireGargoyleOverheadRake"],
	[0x100, 1, "FireGargoyleSwoopingClaw"], [0xffff, 1, "FireGargoyleSwoopingClaw"], [0x1ff, 4, "FireGargoyleOverheadRake"],
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var checks := 0
	for flags: int in [0, 64]:
		var serial := 0x28a8 + flags
		world.game._handle(driver.mobile_packet(at, flags, serial, Body, 0x8035))
		var avatar: Node3D = world.avatars[serial]
		var visual: Node3D = avatar.horse_visual
		for case: Array in AttackCases:
			var expected: String = case[2]
			if not enhanced:
				var parsed := {"serial": serial, "body": Body, "protocol": "new", "type": 0,
					"subaction": case[0], "variation": case[1], "action": 0, "frames": case[0], "delay": case[1]}
				assert(Classic.dispatch(avatar, parsed))
				expected = visual.current_clip
			world.game._handle(Attack.attack_packet(serial, case[0], case[1]))
			assert(visual.current_clip == expected and visual.native_hue == 0x8035)
			checks += 1
	var report := await Replay.run(driver, world, at, enhanced, 0x28a0, Cases)
	report.checks += checks
	if enhanced:
		report.fire_breath = check_breath(driver, world, at)
		report.checks += 10
	return report


static func check_breath(driver, world: Node, at: Vector2i) -> Dictionary:
	var serial := 0x28b0
	world.game._handle(driver.mobile_packet(at, 64, serial, Body, 0x8035))
	var avatar: Node3D = world.avatars[serial]
	var actor: Node3D = avatar.horse_visual
	var effects: Node3D
	for child: Node in world.get_children():
		if child is Projectile:
			effects = child
			break
	assert(effects != null and actor.fire_breath_origin() == null)
	var action := Replay.attack_packet(serial)
	action[6] = 12
	action[8] = 4
	action[11] = 0
	world.game._handle(action)
	assert(actor.current_clip == "Attack" and actor.fire_breath_origin() == null)
	action[8] = 5
	world.game._handle(action)
	assert(actor.current_clip == Breath and actor.get_meta("native_action").frames == 5)
	actor.animator.advance(0.0)
	var start: Vector3 = actor.fire_breath_origin()
	for frame in 78:
		actor.animator.advance(1.0 / 60.0)
		actor._process(1.0 / 60.0)
	actor.play_gait(true, 4.0)
	assert(actor.current_clip == Breath and is_equal_approx(actor.animator.current_animation_position, 1.3))
	var origin: Vector3 = actor.fire_breath_origin()
	assert(start.distance_to(origin) > .09)
	var chest := avatar.global_position + Vector3.UP * 1.2
	assert(chest.distance_to(origin) > .50)
	assert(effects._bolt_origin({"source": serial, "graphic": 0x36d3, "from": Vector3i.ZERO}).is_equal_approx(chest))
	var packet := PackedByteArray([0x70, 0])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(Wire.uint_be(serial + 1, 4))
	packet.append_array(Wire.uint_be(0x36d4, 2))
	packet.append_array(Wire.uint_be(at.x, 2))
	packet.append_array(Wire.uint_be(at.y, 2))
	packet.append(0)
	packet.append_array(Wire.uint_be(at.x + 1, 2))
	packet.append_array(Wire.uint_be(at.y, 2))
	packet.append_array(PackedByteArray([0, 5, 0, 0, 0, 0, 0]))
	var previous: int = effects.get_child_count()
	var phase: String = world.game.phase
	world.game.phase = "world"
	world.game._handle(packet)
	world.game.phase = phase
	assert(effects.get_child_count() == previous + 1)
	var bolt := effects.get_child(previous) as MeshInstance3D
	assert(bolt.global_position.is_equal_approx(origin))
	world.game._handle(Replay.attack_packet(serial))
	assert(actor.current_clip != Breath and actor.get_meta("native_action").action == 4 and actor.fire_breath_origin() == null)
	return {"muzzle_travel": start.distance_to(origin), "chest_distance": chest.distance_to(origin)}
