# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Fit := preload("bake-mummy-balron-enhanced.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")


func _initialize() -> void:
	create_timer(50.0).timeout.connect(func(): quit(2))
	call_deferred("run")


func run() -> void:
	var treatments := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var path := Fit.Destination + "40-%s.scn" % treatment
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_child("Body", true, false) as MeshInstance3D
		var rest: Array[float] = []
		for side: String in ["l", "r"]:
			for link in Fit.WingChain.size() - 1:
				var a := rig.find_bone("daemon " + side + Fit.WingChain[link])
				var b := rig.find_bone("daemon " + side + Fit.WingChain[link + 1])
				rest.append(rig.get_bone_global_rest(a).origin.distance_to(rig.get_bone_global_rest(b).origin))
		var evidence := {"scene_sha256": FileAccess.get_sha256(path), "motions": {}}
		for clip: String in Fit.BalronClips.values():
			player.stop()
			player.play(clip, 0.0)
			player.advance(0.0)
			var intervals := ceili(player.current_animation_length * 480.0)
			var link_error := 0.0
			var max_tip_step := 0.0
			var last: Array[Vector3] = []
			for index in intervals + 1:
				player.seek(player.current_animation_length * index / intervals, true)
				rig.force_update_all_bone_transforms()
				var tips: Array[Vector3] = []
				var link := 0
				for side: String in ["l", "r"]:
					var root_bone := rig.find_bone("daemon " + side + Fit.WingChain[0])
					var previous := rig.get_bone_global_pose(root_bone).origin
					for segment in range(1, Fit.WingChain.size()):
						var bone := rig.find_bone("daemon " + side + Fit.WingChain[segment])
						var current := rig.get_bone_global_pose(bone).origin
						link_error = maxf(link_error, absf(previous.distance_to(current) - rest[link]))
						previous = current
						link += 1
					tips.append(rig.to_global(previous))
				for side in last.size():
					max_tip_step = maxf(max_tip_step, last[side].distance_to(tips[side]))
				last = tips
			assert(link_error < .00005 and max_tip_step < .30, "%s %s: link error %f, tip step %f" % [treatment, clip, link_error, max_tip_step])
			evidence.motions[clip] = {"samples": intervals + 1, "link_error": link_error, "max_tip_step": max_tip_step}
			if clip == Fit.BalronClips[23]:
				player.seek(0.0, true)
				rig.force_update_all_bone_transforms()
				var folded := Geometry.deformed_bounds(mesh, rig)
				player.seek(player.current_animation_length * .74, true)
				rig.force_update_all_bone_transforms()
				var spread := Geometry.deformed_bounds(mesh, rig)
				assert(spread.size.x >= folded.size.x * 1.5)
				evidence.folded_width = folded.size.x
				evidence.open_width = spread.size.x
		treatments[treatment] = evidence
		model.free()
		print("BALRON WING GEOMETRY ", treatment, " ", evidence)
	var report := FileAccess.open(Fit.Destination + "wing-receipt.json", FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify(treatments, "\t"))
	report.close()
	quit()
