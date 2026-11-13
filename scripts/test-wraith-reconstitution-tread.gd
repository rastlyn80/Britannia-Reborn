# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-zombie-wraith-enhanced.gd"

const Tread := .22


func run() -> void:
	create_timer(120.0).timeout.connect(func(): quit(2))
	assert(Installed.enable())
	assert(26 in load("res://Presentation/SourceOccurrenceTerrainProfile.gd").enable())
	using_installed = true
	var lower := make_tread(-6.0, 0.0)
	var upper := make_tread(6.0, Tread)
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.entities[26] = {"serial": 26, "body": 26, "hue": 0x4001}
	await physics_frame
	await physics_frame
	var falls := 0
	var samples := 0
	var maximum_jump := 0.0
	var maximum_join := 0.0
	var minimum := INF
	var packet := decode(game, 26, 15, 0)
	for x: float in [-.22, -.035, .15]:
		for yaw: float in [PI * .5, PI * 1.5]:
			var source := create_fit(26, "modern")
			source.position = Vector3(x, Tread if x > 0.0 else 0.0, 0.0)
			source.rotation.y = yaw
			source._physics_process(1.0 / 60.0)
			assert(source.terrain.split)
			var avatar := Avatar.new()
			avatar.horse_visual = source
			start_motion(avatar, packet)
			var length: float = source.animator.current_animation_length
			var maximum_pieces := 0
			for index in 19:
				var phase := minf(index / 30.0, .5999)
				source.animator.seek(length * phase, true)
				assert(source.pieces.visible and not source.living_mesh.visible)
				var pieces := tread_extent(source)
				assert(pieces.gap >= .0019, "Reconstitution clearance %f at %.4f" % [pieces.gap, phase])
				if index == 0:
					assert(pieces.count == 5)
				maximum_pieces = maxi(maximum_pieces, pieces.count)
			assert(maximum_pieces == 6)
			var before_join: AABB = tread_extent(source).bounds
			source.animator.seek(length * .6001, true)
			assert(source.living_mesh.visible and not source.pieces.visible)
			var after_join := Geometry.deformed_bounds(source.living_mesh, source.skeleton)
			var join_jump := corner_motion(before_join, after_join)
			assert(join_jump < .003, "Join shifted by %f at x %.3f yaw %.3f" % [join_jump, x, yaw])
			maximum_join = maxf(maximum_join, join_jump)
			for phase: float in [.06, .28, .54]:
				start_motion(avatar, packet)
				source.animator.seek(length * phase, true)
				assert(source.pieces.visible and not source.living_mesh.visible)
				var before := tread_extent(source)
				var fallen := create_fit(26, "modern")
				fallen.model.transform = source.model.transform
				fallen.dead = true
				fallen.contact.enabled = false
				assert(is_equal_approx(fallen.begin_death_from(source), .52))
				var after := tread_extent(fallen)
				var jump := corner_motion(before.bounds, after.bounds)
				assert(jump < .002 and after.count == before.count, "Scatter entry shifted by %f" % jump)
				maximum_jump = maxf(maximum_jump, jump)
				for index in 31:
					fallen.advance_scatter(index / 30.0)
					var extent := tread_extent(fallen)
					assert(extent.gap >= .0019 and extent.count == before.count, str(extent))
					minimum = minf(minimum, extent.gap)
					samples += 1
				var frozen := Snapshot.capture(fallen, fallen.corpse_snapshot_floor())
				assert(not frozen.is_empty() and frozen.body == 26)
				var corpse: Node3D = frozen.scene.instantiate()
				assert(corpse.get_child_count() == before.count and corpse.get_meta("native_hue") == 0x4001)
				assert(corpse.get_meta("death_clip") == Scatter and corpse.find_children("*", "Skeleton3D").is_empty())
				check_spectral(corpse)
				corpse.free()
				fallen.free()
				falls += 1
			avatar.free()
			source.free()
	lower.free()
	upper.free()
	game.free()
	assert(falls == 18 and samples == 558)
	print("WRAITH RECONSTITUTION TREAD: 114 assembly poses, ", falls, " falls, ", samples,
		" scatter poses, minimum gap ", minimum, ", maximum fall entry ", maximum_jump, ", maximum join ", maximum_join)
	quit()


func corner_motion(first: AABB, second: AABB) -> float:
	return maxf(first.position.distance_to(second.position), first.end.distance_to(second.end))


func tread_extent(actor: Node3D) -> Dictionary:
	var gap := INF
	var count := 0
	var bounds := AABB()
	for part: MeshInstance3D in actor.piece_points:
		if not part.visible:
			continue
		for vertex: Vector3 in actor.piece_points[part]:
			var point := part.to_global(vertex)
			if is_inf(gap):
				bounds = AABB(point, Vector3.ZERO)
			bounds = bounds.expand(point)
			gap = minf(gap, point.y - (Tread if point.x >= 0.0 else 0.0))
		count += 1
	return {"gap": gap, "count": count, "bounds": bounds}


func make_tread(x: float, height: float) -> StaticBody3D:
	var tread := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(12.0, .2, 12.0)
	collision.shape = shape
	tread.add_child(collision)
	tread.position = Vector3(x, height - .1, 0.0)
	root.add_child(tread)
	return tread
