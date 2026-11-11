# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Renderer := preload("res://Presentation/SourceEnhancedHiryuVisual.gd")
const Stock := preload("res://Presentation/SourceHiryuMountVisual.gd")
const Body := 243
const MountItem := 0x3e94
const Rider := 0x2598
const Joints := ["bip01 head", "bip01 spine", "bip01 tail1", "bip01 r foot"]
const Cases := [
	{"body": Body, "type": 11, "variant": 2, "clip": "HiryuTailFlourish", "phase": .48,
		"hue": 0x8035, "joints": Joints, "recolour": true},
	{"body": Body, "type": 14, "clip": "HiryuWingFeint", "phase": .27, "hue": 53, "joints": Joints},
	{"body": Body, "type": 5, "variant": 1, "flags": 0, "clip": "HiryuLowInspection",
		"phase": .46, "hue": 0x455, "joints": Joints},
]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var result := await Replay.run(driver, world, at, enhanced, 0x2590, Cases)
	for gender: int in [400, 401]:
		result.checks += await check_mounted(driver, world, at, gender, enhanced)
	return result


static func check_mounted(driver, world: Node, at: Vector2i, gender: int, enhanced: bool) -> int:
	var serial := Rider + gender - 400
	var hue := 0x8035 if gender == 400 else 53
	world.game._handle(rider_packet(driver, at, serial, gender, hue))
	var rider: Node3D = world.avatars[serial]
	var mount: Node3D = rider.horse_visual
	assert(mount != null and (mount is Renderer if enhanced else mount is Stock))
	assert(mount.native_body == Body and mount.native_mount_item == MountItem and mount.native_hue == hue)
	assert(rider.human_visual.female == (gender == 401))
	rider.rider_contact.begin_mount(false)
	var clips := Renderer.Seated if enhanced else ["Idle", "Walk", "Run"]
	for stage in 3:
		mount.play_gait(stage > 0, [0.0, 2.0, 5.5][stage])
		assert(mount.current_clip == clips[stage])
	world.game._handle(rider_packet(driver, at, serial, gender))
	assert(not world.game.mobile_equipment.get(serial, {}).has(25))
	assert(rider.retiring_horse and not mount.visible)
	var deadline: SceneTreeTimer = driver.create_timer(2.5)
	while rider.horse_visual != null and deadline.time_left > 0.0:
		await driver.process_frame
	assert(rider.horse_visual == null and rider.rider_contact == null, "The rider did not finish dismounting.")
	return 7


static func rider_packet(driver, at: Vector2i, rider: int, gender: int, mount_hue := -1) -> PackedByteArray:
	var packet := PackedByteArray([0x78, 0, 0])
	packet.append_array(driver.mobile_packet(at, 64, rider, gender, 1002).slice(1))
	if mount_hue >= 0:
		packet.append_array(Wire.uint_be(0x40002000 + rider, 4))
		packet.append_array(Wire.uint_be(MountItem, 2))
		packet.append(25)
		packet.append_array(Wire.uint_be(mount_hue, 2))
	packet.append_array(Wire.uint_be(0, 4))
	packet[1] = packet.size() >> 8
	packet[2] = packet.size() & 0xff
	return packet
