# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Fit := preload("bake-frost-spider-enhanced.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const SampleRate := 240
const Landmarks := ["bone18", "bone22", "bone14", "bone26", "bone10", "bone30", "bone06", "bone34"]


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var results := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var path := Fit.Destination + "20-%s.scn" % treatment
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var skin := Ground.skin_points(model.find_child("Body", true, false), rig)
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var clips := {}
		for group: int in Fit.Clips:
			var name: String = Fit.Clips[group]
			var count := ceili(player.get_animation(name).length * SampleRate)
			player.play(name, 0.0)
			player.advance(0.0)
			var before := tips(rig)
			var minimum_floor := INF
			var minimum_tip_gap := INF
			var support_drift := 0.0
			var foreleg_lift := 0.0
			for step in range(count + 1):
				player.seek(float(step) / count * player.current_animation_length, true)
				rig.force_update_all_bone_transforms()
				var feet := tips(rig)
				minimum_floor = minf(minimum_floor, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
				for i in feet.size():
					for j in range(i + 1, feet.size()):
						minimum_tip_gap = minf(minimum_tip_gap, feet[i].distance_to(feet[j]))
					if i >= 4 and group not in [23, 28]:
						support_drift = maxf(support_drift, (feet[i] - before[i]).slide(Vector3.UP).length())
					if i < 2:
						foreleg_lift = maxf(foreleg_lift, feet[i].y - before[i].y)
			assert(minimum_floor > .0034 and minimum_tip_gap > .15, "%s: floor %.5f and separation %.5f" % [name, minimum_floor, minimum_tip_gap])
			assert(support_drift < .008, "%s: rear foot drift %.5f" % [name, support_drift])
			if group == 15:
				assert(foreleg_lift > .60, "High defence must raise the front legs")
			clips[name] = {"samples": count + 1, "minimum_floor_gap": minimum_floor,
				"minimum_tip_separation": minimum_tip_gap, "maximum_rear_foot_drift": support_drift,
				"maximum_foreleg_lift": foreleg_lift, "rear_stance_measured": group not in [23, 28]}
		results[treatment] = {"scene_sha256": FileAccess.get_sha256(path), "clips": clips}
		model.free()
	var receipt := FileAccess.open(Fit.Destination + "dense-clearance-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"sample_rate": SampleRate, "treatments": results}, "\t"))
	receipt.close()
	print("FROST SPIDER DENSE ", results)
	quit()


func tips(rig: Skeleton3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	for name: String in Landmarks:
		result.append(rig.to_global(rig.get_bone_global_pose(rig.find_bone(name)).origin))
	return result
