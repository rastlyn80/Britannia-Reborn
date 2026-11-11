# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Replay := preload("res://../scripts/test-enhanced-corpse-gesture-cases.gd")
const Fit := preload("test-armored-gargoyles-enhanced.gd")
const Renderer := preload("res://Presentation/SourceEnhancedArmoredGargoyleVisual.gd")
const Presenter := preload("res://Presentation/SourceEnhancedArmoredGargoyleProjectilePresenter.gd")
const Wire := preload("res://Network/LoginProtocol.gd")
const Joints := ["bip01 head", "bip01 r hand", "gargoyle l wing3", "gargoyle r wing3"]


static func check(driver, world: Node, at: Vector2i, enhanced: bool) -> Dictionary:
	var checks := 0
	var poses := {}
	for body: int in [755, 754]:
		var serial := 0x2a00 + body
		world.game._handle(driver.mobile_packet(at, 0x44, serial, body, 0x8035))
		var avatar: Node3D = world.avatars[serial]
		var visual: Node3D = avatar.horse_visual
		assert((visual is Renderer) == enhanced and visual.native_body == body and visual.native_hue == 0x8035)
		checks += 1
		world.game._handle(driver.action_packet(5, serial, 1))
		if enhanced:
			assert(visual.current_clip == "GargoyleNearGlance" and not visual.contact.enabled)
			checks += 1
		var ordinary := Replay.attack_packet(serial)
		world.game._handle(ordinary)
		assert(visual.current_clip == "Attack")
		checks += 1
		var graphic := 0x0f43 if body == 755 else 0x3728
		var packet := Fit.effect_packet(0 if body == 755 else 3, serial, 0, graphic, 10, 0 if body == 755 else 15)
		packet[12] = (at.x >> 8) & 255
		packet[13] = at.x & 255
		packet[14] = (at.y >> 8) & 255
		packet[15] = at.y & 255
		packet[17] = ((at.x + 1) >> 8) & 255
		packet[18] = (at.x + 1) & 255
		packet[19] = (at.y >> 8) & 255
		packet[20] = at.y & 255
		var phase: String = world.game.phase
		world.game.phase = "world"
		world.game._handle(packet)
		world.game.phase = phase
		if enhanced:
			assert(visual.current_clip == (Renderer.Hatchet if body == 755 else Renderer.Sweep))
			checks += 1
			if body == 755:
				var projectile := world.find_child("NativeDestroyerHatchet*", true, false) as Node3D
				assert(projectile != null and projectile.get_child_count() == 2)
				var grip: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.counter_hand).origin)
				assert(projectile.global_position.distance_to(grip) < .00001)
			else:
				world.game._handle(ordinary)
				assert(visual.current_clip == Renderer.Sweep and visual.get_meta("native_action").action == 4)
				assert(visual.find_child("NativeEnforcerWhirlwind", false, false) != null)
			checks += 2
		else:
			assert(visual.current_clip == "Attack")
			checks += 1
		poses[str(body)] = await check_fall(driver, world, at, enhanced, body, serial + 0x200)
		checks += 10 if enhanced else 5
	return {"checks": checks, "falls": poses}


static func check_fall(driver, world: Node, at: Vector2i, enhanced: bool, body: int, serial: int) -> Dictionary:
	var hue := 0x8035
	var corpse := 0x40000000 + serial
	world.game._handle(driver.mobile_packet(at, 64, serial, body, hue))
	var actor: Node3D = world.avatars[serial].horse_visual
	world.game._handle(driver.action_packet(3, serial, 1))
	if enhanced:
		assert(actor.current_clip == "Death2")
		actor.animator.advance(.18)
		actor.animator.seek(.36, true)
		actor.skeleton.force_update_all_bone_transforms()
	var displayed: Array[Vector3] = []
	for joint: String in Joints:
		displayed.append(Replay.point(actor, joint))
	world.game._handle(driver.corpse_packet(at, corpse, body, hue))
	var death := PackedByteArray([0xaf])
	death.append_array(Wire.uint_be(serial, 4))
	death.append_array(Wire.uint_be(corpse, 4))
	death.append_array(Wire.uint_be(0, 4))
	world.game._handle(death)
	var transition: Dictionary = world.creature_deaths.active[serial]
	var fallen: Node3D = transition.visual
	var expected := "Death2" if enhanced else "Death"
	assert(fallen.current_clip == expected and fallen.native_body == body and fallen.native_hue == hue)
	var holder: Node3D = world.world_items.nodes[corpse]
	assert(not holder.visible)
	var jump := 0.0
	if enhanced:
		for index in Joints.size():
			jump = maxf(jump, displayed[index].distance_to(Replay.point(fallen, Joints[index])))
		assert(jump < .003, "Armored gargoyle fall discontinuity %.5f m" % jump)
	await driver.create_timer(float(transition.remaining) + .15).timeout
	assert(holder.visible)
	var frozen: Node3D = holder.get_node("CorpseVisual")
	assert(frozen.get_meta("native_hue") == hue and frozen.get_meta("death_clip") == expected)
	assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
	if enhanced:
		assert(world.world_items.corpse_snapshots.has(corpse))
		var before := frozen.global_transform
		var bounds: AABB = frozen.get_meta("corpse_bounds")
		world.game._handle(driver.corpse_packet(at, corpse, body, 0x489))
		var dyed: Node3D = world.world_items.nodes[corpse].get_node("CorpseVisual")
		assert(dyed.get_meta("native_hue") == 0x489 and dyed.get_meta("death_clip") == "Death2")
		assert(dyed.global_transform.is_equal_approx(before) and dyed.get_meta("corpse_bounds") == bounds)
	return {"corpse": corpse, "jump": jump}
