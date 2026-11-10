# SPDX-License-Identifier: GPL-3.0-or-later
extends "bake-ice-elemental-enhanced.gd"

const Proxy := preload("res://../scripts/ophidian-bardiche-clearance.gd")
const Rate := 360.0


func run() -> void:
	var evidence := {}
	var failed := false
	for treatment: String in Profile.registered_assets(Registry.entry(161)):
		var path := Destination + "161-%s.scn" % treatment
		var actor := (load(path) as PackedScene).instantiate()
		root.add_child(actor)
		var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var body := actor.find_child("Body", true, false) as MeshInstance3D
		var crystal := actor.find_child("IceCrystalShell", true, false) as MeshInstance3D
		var body_proxy := Proxy.new(body, rig)
		var shell := Ground.skin_points(crystal, rig)
		var left := find_blade(crystal, rig, "l")
		var right := find_blade(crystal, rig, "r")
		var clips := {}
		for clip: String in Clips.values() + ["Idle", "Walk", "Run", "Death", "Death2"]:
			var result := inspect_clip(player, rig, body_proxy, shell, left, right, clip)
			failed = failed or result.body_crossings > 0 or result.minimum_blade_distance < .08
			if clip not in ["Death", "Death2"]:
				failed = failed or result.lowest_y < .002
			clips[clip] = result
		evidence[treatment] = {"clips": clips, "scene_sha256": FileAccess.get_sha256(path)}
		actor.free()
	var file := FileAccess.open(Destination + "crystal-clearance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"inspection_rate": Rate, "failed": failed, "treatments": evidence}, "\t"))
	file.close()
	quit(int(failed))


func find_blade(mesh: MeshInstance3D, rig: Skeleton3D, side: String) -> Dictionary:
	return {"joint": rig.find_bone(CrystalShell.BladeJoint[side]), "tip": CrystalShell.local_tip(mesh, rig, side)}


func inspect_clip(player: AnimationPlayer, rig: Skeleton3D, body: Proxy, shell: Dictionary,
		left: Dictionary, right: Dictionary, clip: String) -> Dictionary:
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var duration := player.current_animation_length
	var samples := ceili(duration * Rate)
	var result := {"samples": samples + 1, "body_crossings": 0, "minimum_blade_distance": INF, "lowest_y": INF,
		"first_crossing_phase": -1.0, "closest_phase": 0.0}
	for sample in samples + 1:
		player.seek(duration * sample / samples, true)
		rig.force_update_all_bone_transforms()
		body.update_pose()
		var a := blade_segment(rig, left)
		var b := blade_segment(rig, right)
		if intersects_body(body, a) or intersects_body(body, b):
			if result.body_crossings == 0:
				result.first_crossing_phase = float(sample) / samples
			result.body_crossings += 1
		var nearest := Geometry3D.get_closest_points_between_segments(a[0], a[1], b[0], b[1])
		var separation := nearest[0].distance_to(nearest[1])
		if separation < result.minimum_blade_distance:
			result.minimum_blade_distance = separation
			result.closest_phase = float(sample) / samples
		result.lowest_y = minf(result.lowest_y, Ground.minimum_plane_gap(shell, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
	print("ICE CRYSTAL ", clip, " ", result)
	return result


func blade_segment(rig: Skeleton3D, blade: Dictionary) -> Array[Vector3]:
	var pose := rig.global_transform * rig.get_bone_global_pose(blade.joint)
	var tip: Vector3 = blade.tip
	# The shallow root lies inside the hand on purpose. Inspect the cutting edge.
	return [pose * (tip * .44), pose * tip]


func intersects_body(body: Proxy, segment: Array[Vector3]) -> bool:
	var bounds := AABB(segment[0], Vector3.ZERO).expand(segment[1]).grow(.0001)
	for triangle in body.bounds.size():
		if not bounds.intersects(body.bounds[triangle]):
			continue
		var first := triangle * 3
		if Geometry3D.segment_intersects_triangle(segment[0], segment[1], body.deformed[body.indices[first]],
				body.deformed[body.indices[first + 1]], body.deformed[body.indices[first + 2]]) != null:
			return true
	return false
