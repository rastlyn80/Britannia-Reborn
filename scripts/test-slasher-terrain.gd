# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-source-occurrence-terrain.gd"

const Slasher := preload("res://Presentation/SlasherProfile.gd")


func run() -> void:
	assert(Slasher.enable())
	var floor := floor_box()
	var tread := floor_box()
	tread.position = Vector3(6.0, Step - .1, 0.0)
	(tread.get_child(0).shape as BoxShape3D).size = Vector3(12.0, .2, 16.0)
	var motions: Array = Slasher.Classic.values()
	var tested := 0
	var least := INF
	var most_lift := 0.0
	var lift_case := ""
	for surface: String in ["flat", "slope", "step"]:
		var stepped := surface == "step"
		var normal := Vector3(.14, 1.0, -.09).normalized() if surface == "slope" else Vector3.UP
		var middle := Vector3(-6.0, 0.0, 0.0) if stepped else Vector3.ZERO
		floor.transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), middle - .1 * normal)
		(floor.get_child(0).shape as BoxShape3D).size = Vector3(12.0 if stepped else 24.0, .2, 16.0)
		tread.collision_layer = 1 if stepped else 0
		await physics_frame
		await physics_frame
		for style: String in ["original", "rounded", "modern"]:
			var slasher := Registry.create(Slasher.Body)
			slasher.treatment = style
			root.add_child(slasher)
			slasher.set_process(false)
			slasher.set_physics_process(false)
			slasher.apply_identity(Slasher.Body, 0x8035)
			var rig: Skeleton3D = slasher.skeleton
			var animator: AnimationPlayer = slasher.animator
			animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var checked := {}
			for clip: String in motions:
				if checked.has(clip) or clip in ["Death", "Death2"]:
					continue
				checked[clip] = true
				for facing: float in [0.0, PI * .5]:
					slasher.position = Vector3(-.26, 0.0, 0.0) if stepped else Vector3.ZERO
					var point := slasher.position
					slasher.rotation.y = facing
					slasher.current_clip = clip
					animator.play(clip, 0.0)
					animator.advance(0.0)
					for sample in 13:
						animator.seek(animator.current_animation_length * float(sample) / 12.0, true)
						slasher._physics_process(1.0 / 60.0)
						rig.force_update_all_bone_transforms()
						var gap: float = slasher.terrain.step_gap(rig) if stepped else Ground.minimum_plane_gap(
							slasher.terrain.skin, rig, rig.global_transform, Vector3.ZERO, normal)
						assert(is_finite(gap) and gap >= -.001 and point == slasher.position and slasher.native_hue == 0x8035,
							"%s %s %s %.6f" % [surface, style, clip, gap])
						least = minf(least, gap)
						if most_lift < slasher.terrain.live_lift:
							most_lift = slasher.terrain.live_lift
							lift_case = "%s %s %s frame %d" % [surface, style, clip, sample]
						tested += 1
			slasher.free()
	print("SLASHER TERRAIN: ", tested, " poses, minimum gap ", least, " m, maximum model lift ", most_lift, " m (", lift_case, ")")
	quit()
