# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const MageJoints := ["bip01 head", "cp_grasp_rhand", "ratman mage crook"]
const LavaJoints := ["bip01 head", "bip01 neck2", "bip01 tail4"]
const Crook := ["RatmanCrook"]
const Sword := ["RatmanSword"]
const Wire := preload("res://Network/LoginProtocol.gd")
const Projectile := preload("res://Presentation/CreatureProjectilePresenter.gd")
const Breath := "LavaSerpentFireBreath"
const Cases := [
	{"body": 143, "type": 2, "clip": "RatmanMageGuardRecoil", "phase": .38, "hue": 0x8035, "joints": MageJoints,
		"visible": Crook, "hidden": Sword, "recolour": true},
	{"body": 143, "type": 5, "clip": "RatmanMageCrookWatch", "phase": .45, "hue": 0x455, "joints": MageJoints, "visible": Crook, "hidden": Sword},
	{"body": 143, "type": 5, "variant": 1, "clip": "RatmanMageCrookSweep", "phase": .60, "hue": 0x489, "joints": MageJoints, "visible": Crook, "hidden": Sword},
	{"body": 143, "type": 8, "clip": "RatmanMageHighAlert", "phase": .75, "hue": 0x455, "joints": MageJoints, "visible": Crook, "hidden": Sword},
	{"body": 143, "type": 11, "clip": "RatmanMageCrookCast", "phase": .46, "hue": 0x8035, "joints": MageJoints, "visible": Crook, "hidden": Sword},
	{"body": 143, "type": 14, "clip": "RatmanMageLowClawBrace", "phase": .58, "hue": 0x455, "joints": MageJoints, "visible": Crook, "hidden": Sword},
	{"body": 143, "type": 15, "clip": "RatmanMageHoodedRise", "phase": .20, "hue": 0x489, "joints": MageJoints, "visible": Crook, "hidden": Sword},
	{"body": 90, "type": 8, "clip": "LavaSerpentCoiledAlert", "phase": .63, "hue": 0x455, "joints": LavaJoints},
	{"body": 90, "type": 11, "clip": "LavaSerpentCoilLash", "phase": .38, "hue": 0x8035, "joints": LavaJoints},
	{"body": 90, "type": 15, "clip": "LavaSerpentThreadEmergence", "phase": .15, "hue": 0x489, "joints": LavaJoints},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var report := await Replay.run(driver, world, at, enhanced, 0x1da0, Cases)
	var case: Dictionary = report.rows.RatmanMageGuardRecoil
	var corpse: Node3D = world.world_items.nodes[case.corpse].get_node("CorpseVisual")
	if enhanced:
		assert(corpse.has_node("RatmanCrook") and not corpse.has_node("RatmanSword"))
		var crook := corpse.get_node("RatmanCrook") as MeshInstance3D
		assert(crook.get_active_material(0) is StandardMaterial3D)
		if "--recolour-optional-props" in OS.get_cmdline_user_args():
			assert(corpse.get_meta("native_hue") == 0x489)
	else:
		assert(corpse.has_node("RatmanSword") and not corpse.has_node("RatmanCrook"))
	report.checks += 1
	if enhanced:
		report.fire_breath = check_breath(driver, world, at)
		report.checks += 8
	return report


static func check_breath(driver, world: Node, at: Vector2i) -> Dictionary:
	var serial := 0x1db0
	world.game._handle(driver.mobile_packet(at, 64, serial, 90, 0x8035))
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
	action[11] = 0
	world.game._handle(action)
	assert(actor.current_clip == Breath and actor.get_meta("native_action").frames == 5)
	var jaw: int = actor.skeleton.find_bone("bip01 ponytail1")
	actor.animator.advance(0.0)
	var closed: Quaternion = actor.skeleton.get_bone_pose_rotation(jaw)
	for frame in 78:
		actor.animator.advance(1.0 / 60.0)
		actor._process(1.0 / 60.0)
	actor.play_gait(true, 4.0)
	assert(actor.current_clip == Breath and is_equal_approx(actor.animator.current_animation_position, 1.3))
	var opening := closed.angle_to(actor.skeleton.get_bone_pose_rotation(jaw))
	assert(opening > .35)
	var origin: Vector3 = actor.fire_breath_origin()
	var chest := avatar.global_position + Vector3.UP * 1.2
	assert(chest.distance_to(origin) > .50)
	assert(effects._bolt_origin({"source": serial, "graphic": 0x36d3, "from": Vector3i.ZERO}).is_equal_approx(chest))
	var packet := PackedByteArray([0x70, 0])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(Wire.uint_be(serial + 1, 4))
	packet.append_array(Wire.uint_be(0x36d4, 2))
	packet.append_array(PackedByteArray([0, 1, 0, 1, 0, 0, 2, 0, 2, 0, 5, 0, 0, 0, 0, 0]))
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
	return {"jaw_open_radians": opening, "chest_distance": chest.distance_to(origin)}
