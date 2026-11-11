# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Fit := preload("bake-hydra-enhanced.gd")
const Surface := preload("res://../scripts/ophidian-bardiche-clearance.gd")
const Landmarks := ["bip01 head", "bip01 r finger0", "bip01 l finger0", "bip01 r foot", "bip01 l foot"]
const SampleRate := 240


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var result := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var path := Fit.Destination + "265-%s.scn" % treatment
		var actor := (load(path) as PackedScene).instantiate()
		root.add_child(actor)
		var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := actor.find_child("Body", true, false) as MeshInstance3D
		var skin := Surface.new(mesh, rig)
		var support := PackedInt32Array()
		for index in skin.positions.size():
			var slot: int = index * skin.stride
			var trunk_weight := 0.0
			for influence in skin.stride:
				var weight: float = skin.weights[slot + influence]
				if weight <= 0.0:
					continue
				var bone := rig.get_bone_name(skin.bones[skin.joints[slot + influence]])
				if bone.begins_with("bip01 tail") or bone in ["bip01 pelvis", "bip01 spine"]:
					trunk_weight += weight
			if trunk_weight > .65:
				support.append(index)
		assert(not support.is_empty())
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var motions := {}
		for clip: String in Fit.Clips.values():
			player.play(clip, 0.0)
			player.advance(0.0)
			var intervals := ceili(player.current_animation_length * SampleRate)
			var head_start := heads(rig)
			var max_travel := PackedFloat32Array()
			max_travel.resize(Landmarks.size())
			var nearest := INF
			var minimum_floor := INF
			var maximum_support_gap := 0.0
			for i in intervals + 1:
				player.seek(player.current_animation_length * float(i) / intervals, true)
				rig.force_update_all_bone_transforms()
				skin.update_pose()
				var lowest := INF
				for vertex: Vector3 in skin.deformed:
					lowest = minf(lowest, vertex.y)
				minimum_floor = minf(minimum_floor, lowest)
				var support_floor := INF
				for index: int in support:
					support_floor = minf(support_floor, skin.deformed[index].y)
				maximum_support_gap = maxf(maximum_support_gap, support_floor - lowest)
				var posed := heads(rig)
				for a in posed.size():
					max_travel[a] = maxf(max_travel[a], head_start[a].distance_to(posed[a]))
					for b in range(a + 1, posed.size()):
						nearest = minf(nearest, posed[a].distance_to(posed[b]))
			motions[clip] = {"samples": intervals + 1, "minimum_head_separation": nearest,
				"minimum_floor_gap": minimum_floor, "maximum_trunk_or_tail_gap": maximum_support_gap,
				"head_travel": Array(max_travel)}
			print("HYDRA CLEARANCE ", treatment, "/", clip, " ", motions[clip])
		result[treatment] = {"scene_sha256": FileAccess.get_sha256(path), "clips": motions}
		actor.free()
	var output := FileAccess.open(Fit.Destination + "dense-clearance-receipt.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"sample_rate": SampleRate, "treatments": result}, "\t"))
	output.close()
	quit()


func heads(rig: Skeleton3D) -> PackedVector3Array:
	var positions := PackedVector3Array()
	for joint: String in Landmarks:
		var bone := rig.find_bone(joint)
		positions.append(rig.to_global(rig.get_bone_global_pose(bone).origin))
	return positions
