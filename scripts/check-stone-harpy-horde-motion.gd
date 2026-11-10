# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Batch := preload("bake-stone-harpy-horde-minion-enhanced.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Rate := 240


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var bodies := {}
	var failed := false
	for body: int in [73, 776]:
		var treatments := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var path := Batch.Destination + "%d-%s.scn" % [body, treatment]
			var model := (load(path) as PackedScene).instantiate()
			root.add_child(model)
			var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var mesh := model.find_child("Body", true, false) as MeshInstance3D
			var skin := Ground.skin_points(mesh, rig)
			var results := {}
			var fitted := Batch.Stone if body == 73 else Batch.Horde
			for group: int in fitted:
				var measurements := sample_motion(rig, player, skin, fitted[group])
				results[fitted[group]] = measurements
				failed = failed or measurements.floor_minimum < -.003 or measurements.maximum_tip_step > .10
				print("FITTED MOTION ", body, "/", treatment, "/", group, " ", measurements)
			treatments[treatment] = {"scene_sha256": FileAccess.get_sha256(path), "clips": results}
			model.free()
		bodies[str(body)] = treatments
	var receipt := FileAccess.open(Batch.Destination + "dense-motion-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"sample_rate": Rate, "passed": not failed, "bodies": bodies}, "\t"))
	receipt.close()
	quit(1 if failed else 0)


func sample_motion(rig: Skeleton3D, player: AnimationPlayer, skin: Dictionary, clip: String) -> Dictionary:
	player.stop()
	player.play(clip, 0.0)
	player.advance(0.0)
	var intervals := ceili(player.current_animation_length * Rate)
	var floor_minimum := INF
	var floor_maximum := -INF
	var narrowest := INF
	var widest := 0.0
	var highest_hand := -INF
	var lowest_pelvis := INF
	var maximum_tip_step := 0.0
	var left := rig.find_bone("bip01 l hand")
	var right := rig.find_bone("bip01 r hand")
	var pelvis := rig.find_bone("bip01 pelvis")
	var last_left := Vector3.ZERO
	var last_right := Vector3.ZERO
	for sample in intervals + 1:
		player.seek(player.current_animation_length * sample / intervals, true)
		rig.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		floor_minimum = minf(floor_minimum, gap)
		floor_maximum = maxf(floor_maximum, gap)
		var l := rig.to_global(rig.get_bone_global_pose(left).origin)
		var r := rig.to_global(rig.get_bone_global_pose(right).origin)
		var span := l.distance_to(r)
		narrowest = minf(narrowest, span)
		widest = maxf(widest, span)
		highest_hand = maxf(highest_hand, maxf(l.y, r.y))
		lowest_pelvis = minf(lowest_pelvis, rig.to_global(rig.get_bone_global_pose(pelvis).origin).y)
		if sample > 0:
			maximum_tip_step = maxf(maximum_tip_step, maxf(l.distance_to(last_left), r.distance_to(last_right)))
		last_left = l
		last_right = r
	return {"samples": intervals + 1, "floor_minimum": floor_minimum, "floor_maximum": floor_maximum,
		"minimum_tip_span": narrowest, "maximum_tip_span": widest, "maximum_tip_step": maximum_tip_step,
		"highest_hand": highest_hand, "lowest_pelvis": lowest_pelvis}
