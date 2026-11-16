# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-source-occurrence-terrain.gd"

const Medusa := preload("res://Presentation/MedusaProfile.gd")


func run() -> void:
	assert(Medusa.enable())
	var floor := floor_box()
	var tread := floor_box()
	tread.position = Vector3(6.0, Step - .1, 0.0)
	(tread.get_child(0).shape as BoxShape3D).size = Vector3(12.0, .2, 16.0)
	var motions: Array = Medusa.Classic.values()
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
			var medusa := Registry.create(Medusa.Body)
			medusa.treatment = style
			root.add_child(medusa)
			medusa.set_process(false)
			medusa.set_physics_process(false)
			medusa.apply_identity(Medusa.Body, 0x8035)
			var rig: Skeleton3D = medusa.skeleton
			var animator: AnimationPlayer = medusa.animator
			animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var checked := {}
			for clip: String in motions:
				if checked.has(clip) or clip in ["Death", "Death2"]:
					continue
				checked[clip] = true
				for facing: float in [0.0, PI * .5]:
					medusa.position = Vector3(-.26, 0.0, 0.0) if stepped else Vector3.ZERO
					var point := medusa.position
					medusa.rotation.y = facing
					medusa.current_clip = clip
					animator.play(clip, 0.0)
					animator.advance(0.0)
					for sample in 13:
						animator.seek(animator.current_animation_length * float(sample) / 12.0, true)
						medusa._physics_process(1.0 / 60.0)
						rig.force_update_all_bone_transforms()
						var gap: float = medusa.terrain.step_gap(rig) if stepped else Ground.minimum_plane_gap(
							medusa.terrain.skin, rig, rig.global_transform, Vector3.ZERO, normal)
						assert(is_finite(gap) and gap >= -.001 and point == medusa.position and medusa.native_hue == 0x8035,
							"%s %s %s %.6f" % [surface, style, clip, gap])
						least = minf(least, gap)
						if most_lift < medusa.terrain.live_lift:
							most_lift = medusa.terrain.live_lift
							lift_case = "%s %s %s frame %d" % [surface, style, clip, sample]
						tested += 1
			medusa.free()
	print("MEDUSA TERRAIN: ", tested, " poses, minimum gap ", least, " m, maximum model lift ", most_lift, " m (", lift_case, ")")
	quit()
