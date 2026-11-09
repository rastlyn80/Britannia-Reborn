# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-centaur-through-essence-actions.gd"

const BowVisual := preload("res://Presentation/CentaurBowVisual.gd")
const TRIAL := "res://local-art/creatures/centaur-binding-trial/"
const MOTIONS := ["Idle", "Walk", "Run", "Attack", "Attack2", "Hit", "Death", "CentaurShoulderBrace"]
const BOW_GRIP := Vector3(-0.00084, 0.02968, -0.00540)

func _initialize() -> void:
	create_timer(95.).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	Registry.load_index()
	var old := Registry.entry(101)
	var active := "--active" in OS.get_cmdline_user_args()
	var row := old.duplicate(true)
	var index := "res://local-art/creatures/accepted-index.json"
	var digest := FileAccess.get_sha256(index)
	if active:
		assert(row.has("mesh_binding_native_sha256") and row.presentation_script == "res://Presentation/CentaurBowVisual.gd")
	else:
		for treatment: String in row.assets:
			row.assets[treatment] = TRIAL + "centaur-skin-actions-%s.scn" % treatment
	Registry.entries[101] = row
	var limits := {}
	var count := 0
	for treatment: String in row.assets:
		var actor := BowVisual.new()
		actor.entry = row
		actor.treatment = treatment
		root.add_child(actor)
		actor.apply_identity(101, 0x8035)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.contact.active = false
		actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		actor.set_equipment([{"id": 0x13b2, "layer": 2, "hue": 0x8035}])
		assert(actor.skeleton.get_bone_count() == 47 and actor.bow_id == 0x13b2 and actor.bow_hue == 0x8035)
		var mesh: MeshInstance3D = actor.model.find_children("*", "MeshInstance3D", true, false)[0]
		var skin := Ground.skin_points(mesh, actor.skeleton)
		var bow_points: PackedVector3Array = actor.bow_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var detail := {}
		for motion: String in MOTIONS:
			actor.dead = motion == "Death"
			actor.animator.stop()
			actor.animator.play(motion, 0.0)
			actor.animator.advance(0.0)
			var length := actor.animator.get_animation(motion).length
			var skin_floor := INF
			var bow_floor := INF
			for sample in 25:
				actor.animator.seek(length * float(sample) / 24.0, true)
				actor.skeleton.force_update_all_bone_transforms()
				actor.sync_bow()
				var current := Ground.minimum_plane_gap(skin, actor.skeleton, actor.skeleton.global_transform, Vector3.ZERO, Vector3.UP)
				skin_floor = minf(current, skin_floor)
				assert(is_finite(current) and current >= -0.004, str([treatment, motion, sample, current]))
				assert(actor.bow.visible == (motion != "Death"))
				if actor.bow.visible:
					var palm := actor.left_palm()
					var hoof := actor.skeleton.find_bone("bip01 l hand")
					var hoof_point := actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(hoof).origin)
					assert(actor.bow.to_global(BOW_GRIP).distance_to(palm) < 0.002 and palm.distance_to(hoof_point) > 0.25)
					for point: Vector3 in bow_points:
						bow_floor = minf(bow_floor, actor.bow_mesh.to_global(point).y)
				count += 1
			assert(motion == "Death" or bow_floor >= -0.008, str([treatment, motion, bow_floor]))
			detail[motion] = [skin_floor, bow_floor if is_finite(bow_floor) else null]
			print("CENTAUR ", treatment, " ", motion, " floor ", detail[motion])
		limits[treatment] = detail
		actor.queue_free()
		await process_frame
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for treatment: String in row.assets:
			sample_ranked_ground(plane, 101, treatment)
		plane.free()
		await physics_frame
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(101, hue)
		assert(corpse.get_meta("corpse_body") == 101 and corpse.get_meta("native_hue") == hue)
		assert(corpse.get_meta("static_cadaver") and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
		static_corpses += 1
	Registry.entries[101] = old
	assert(FileAccess.get_sha256(index) == digest and ground_poses == 279 and count == 600 and static_corpses == 3)
	var report := FileAccess.open("res://../work/creatures/centaur-bow-trial/skin-floor.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"flat_poses": count, "brace_slope_poses": ground_poses, "corpse_cases": static_corpses,
		"floor_metres": limits, "minimum_brace_slope": lowest, "failures": 0}, "\t"))
	report.close()
	print("CENTAUR BINDING AND BOW: ", count, " complete skin/held poses, ", ground_poses, " terrain brace poses, ", static_corpses, " corpse hues")
	quit()
