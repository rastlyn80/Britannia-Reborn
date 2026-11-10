# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Wire := preload("res://Network/LoginProtocol.gd")


static func run(driver, world: Node, at: Vector2i, enhanced: bool, first_serial: int, cases: Array) -> Dictionary:
	var rows := {}
	for info: Dictionary in cases:
		var result := await witness(driver, world, at, enhanced, info, first_serial + rows.size())
		assert(not result.is_empty())
		rows[info.get("label", info.clip)] = result
	return {"rows": rows, "checks": cases.size() * (8 if enhanced else 6)}


static func point(actor: Node3D, joint: String) -> Vector3:
	var rig: Skeleton3D = actor.skeleton
	return rig.to_global(rig.get_bone_global_pose(rig.find_bone(joint)).origin)


static func attack_packet(serial: int) -> PackedByteArray:
	var packet := PackedByteArray([0x6e])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(Wire.uint_be(4, 2))
	packet.append_array(Wire.uint_be(5, 2))
	packet.append_array(Wire.uint_be(1, 2))
	packet.append_array(PackedByteArray([1, 0, 0]))
	return packet


static func witness(driver, world: Node, at: Vector2i, enhanced: bool, info: Dictionary, serial: int) -> Dictionary:
	var body: int = info.body
	var hue: int = info.hue
	var corpse := 0x40000000 + serial
	var flags: int = info.get("flags", 64) if enhanced else 64
	var fall_clip := "AirDeath" if (flags & 4) != 0 else "Death"
	world.game._handle(driver.mobile_packet(at, flags, serial, body, hue))
	var source: Node3D = world.avatars[serial].horse_visual
	assert(source.native_body == body and source.native_hue == hue)
	var before: Array[Vector3] = []
	if enhanced:
		world.game._handle(driver.action_packet(info.type, serial, info.get("variant", 0)))
		assert(source.current_clip == info.clip)
		for frame in 10:
			source.animator.advance(.016)
		source.animator.seek(source.animator.current_animation_length * info.phase, true)
		if info.get("interrupt", false):
			world.game._handle(attack_packet(serial))
			assert(source.current_clip == "Attack")
			source.animator.advance(.037)
			assert(source.growth.active)
		source.rotate_y(.32)
		source._physics_process(1.0 / 60.0)
		source.contact.modification_processed.emit()
		for joint: String in info.joints:
			before.append(point(source, joint))
	var corpse_first := serial % 2 == 0
	if corpse_first:
		world.game._handle(driver.corpse_packet(at, corpse, body, hue))
	var death := PackedByteArray([0xaf])
	death.append_array(Wire.uint_be(serial, 4))
	death.append_array(Wire.uint_be(corpse, 4))
	death.append_array(Wire.uint_be(0, 4))
	world.game._handle(death)
	if not corpse_first:
		world.game._handle(driver.corpse_packet(at, corpse, body, hue))
	var state: Dictionary = world.creature_deaths.active[serial]
	var fallen: Node3D = state.visual
	assert(fallen.current_clip == fall_clip and fallen.native_hue == hue)
	var jump := 0.0
	for index in before.size():
		jump = maxf(jump, before[index].distance_to(point(fallen, info.joints[index])))
	if enhanced:
		assert(jump < .002, "%s fall moved a displayed joint by %.7f m" % [info.clip, jump])
	var holder: Node3D = world.world_items.nodes[corpse]
	assert(not holder.visible)
	await driver.create_timer(float(state.remaining) + .15).timeout
	assert(holder.visible and (not enhanced or world.world_items.corpse_snapshots.has(corpse)))
	var frozen: Node3D = holder.get_node("CorpseVisual")
	assert(frozen.get_meta("native_hue") == hue and frozen.get_meta("death_clip") == fall_clip)
	assert(frozen.find_children("*", "Skeleton3D", true, false).is_empty())
	if enhanced:
		for part: String in info.get("visible", []):
			assert(frozen.find_child(part, true, false) != null)
		for part: String in info.get("hidden", []):
			assert(frozen.find_child(part, true, false) == null)
		if info.get("recolour", false) and "--recolour-optional-props" in OS.get_cmdline_user_args():
			var new_hue := 0x489
			var placement := frozen.global_transform
			var bounds: AABB = frozen.get_meta("corpse_bounds")
			world.game._handle(driver.corpse_packet(at, corpse, body, new_hue))
			holder = world.world_items.nodes[corpse]
			frozen = holder.get_node("CorpseVisual")
			assert(frozen.get_meta("native_hue") == new_hue)
			for part: String in info.get("hidden", []):
				assert(frozen.find_child(part, true, false) == null, "A new corpse hue must preserve hidden props")
			assert(frozen.global_transform.is_equal_approx(placement) and frozen.get_meta("corpse_bounds") == bounds)
			var palette := preload("res://Presentation/HumanHue.gd").palette(new_hue)
			assert(palette != null)
			var dyed := false
			for part: MeshInstance3D in frozen.get_children():
				for surface in part.mesh.get_surface_count():
					var material := part.get_active_material(surface) as ShaderMaterial
					if material != null and material.get_shader_parameter("hue_palette") == palette:
						dyed = true
			assert(dyed, "The retained corpse must use the actual new palette")
	return {"body": body, "hue": hue, "jump": jump, "corpse": corpse}
