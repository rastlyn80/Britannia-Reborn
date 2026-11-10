# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Corpses := preload("res://Presentation/CorpseModels.gd")
const BODY := 789
const METRES_PER_SOURCE_UNIT := .01
const PATH := "res://local-art/creatures/quagmire-metres-"
const CLIPS := ["Idle", "Walk", "Run", "Attack", "Attack2", "Hit", "Death", "Fidget", "QuagmireDrawIn", "QuagmireFan"]

func _initialize() -> void:
	create_timer(90.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	Registry.load_index()
	var row := Registry.entry(BODY).duplicate(true)
	var candidate := "--candidate" in OS.get_cmdline_user_args()
	var source: Dictionary = row.get("quagmire_metres", {}).get("source_assets", row.assets)
	if "--bake" in OS.get_cmdline_user_args():
		assert(candidate)
		bake(source)
	if candidate:
		for treatment: String in source:
			row.assets[treatment] = PATH + treatment + ".scn"
	else:
		assert(float(row.quagmire_metres.factor) == METRES_PER_SOURCE_UNIT)
	Registry.entries[BODY] = row
	var poses := 0
	var terrain := 0
	var lowest := INF
	var hashes := {}
	for treatment: String in source:
		var actor := Registry.create(BODY)
		actor.treatment = treatment
		root.add_child(actor)
		actor.apply_identity(BODY, 0x8035)
		var mesh: MeshInstance3D = actor.model.find_children("*", "MeshInstance3D", true, false)[0]
		var rig: Skeleton3D = actor.skeleton
		var anchor := actor.global_transform
		assert(actor.model.scale.is_equal_approx(Vector3.ONE * METRES_PER_SOURCE_UNIT))
		assert(actor.animator.has_animation("QuagmireDrawIn") and actor.animator.has_animation("QuagmireFan"))
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.contact.active = false
		actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		for clip: String in CLIPS:
			actor.animator.play(clip, 0.0)
			actor.animator.advance(0.0)
			for step in 13:
				actor.animator.seek(actor.animator.current_animation_length * float(step) / 12.0, true)
				rig.force_update_all_bone_transforms()
				var bounds := Geometry.deformed_bounds(mesh, rig)
				assert(bounds.is_finite() and bounds.size.y > .4 and bounds.size.y < 4.0 and bounds.size.length() < 9.0,
					str([treatment, clip, step, bounds]))
				assert(actor.global_transform == anchor)
				if clip == "Idle":
					assert(bounds.position.y > -.015 and bounds.size.y > 1.65 and bounds.size.y < 2.3)
				poses += 1
		hashes[treatment] = FileAccess.get_sha256(row.assets[treatment])
		var skin := Ground.skin_points(mesh, rig)
		for tilt: Vector3 in [Vector3.ZERO, Vector3(.10, 0, -.12), Vector3(-.10, 0, .12)]:
			var plane := surface(tilt)
			await physics_frame
			await physics_frame
			var normal := plane.global_basis.y.normalized()
			for clip: String in ["QuagmireDrawIn", "QuagmireFan"]:
				actor.current_clip = clip
				actor.animator.play(clip, 0.0)
				actor.animator.advance(0.0)
				for step in 13:
					actor.animator.seek(actor.animator.current_animation_length * float(step) / 12.0, true)
					actor._physics_process(1.0 / 60.0)
					actor.contact._process_modification_with_delta(1.0 / 60.0)
					rig.force_update_all_bone_transforms()
					actor.contact.modification_processed.emit()
					var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
					assert(is_finite(gap) and gap > .0004 and actor.global_transform == anchor,
						str([treatment, clip, tilt, step, gap]))
					lowest = minf(lowest, gap)
					terrain += 1
			plane.queue_free()
			await process_frame
		actor.queue_free()
		await process_frame
	for hue: int in [0, 53, 0x8035]:
		var corpse := Corpses.build(BODY, hue)
		assert(corpse != null and corpse.get_meta("corpse_body") == BODY and corpse.get_meta("native_hue") == hue)
		var bounds: AABB = corpse.get_meta("corpse_bounds")
		assert(bounds.size.length() < 9.0 and corpse.find_children("*", "Skeleton3D", true, false).is_empty())
		corpse.free()
	if candidate:
		var path := "res://../work/creatures/native-form-audit/quagmire-metres-client.json"
		var file := FileAccess.open(path, FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify({"poses": poses, "terrain": terrain, "minimum_gap": lowest,
			"corpse_hues": 3, "assets_sha256": hashes, "factor": METRES_PER_SOURCE_UNIT,
			"test_sha256": FileAccess.get_sha256(get_script().resource_path)}, "\t"))
		file.close()
	print("QUAGMIRE METRES: ", poses, " complete poses, ", terrain, " finite terrain poses, minimum gap ", lowest,
		", three corpse hues")
	quit()

func bake(sources: Dictionary) -> void:
	for treatment: String in sources:
		var packed := load(sources[treatment]) as PackedScene
		assert(packed != null)
		var scene := packed.instantiate() as Node3D
		root.add_child(scene)
		assert(scene.scale.is_equal_approx(Vector3.ONE))
		scene.scale = Vector3.ONE * METRES_PER_SOURCE_UNIT
		var corrected := PackedScene.new()
		assert(corrected.pack(scene) == OK)
		assert(ResourceSaver.save(corrected, PATH + treatment + ".scn", ResourceSaver.FLAG_COMPRESS) == OK)
		scene.free()

func surface(tilt: Vector3) -> StaticBody3D:
	var plane := StaticBody3D.new()
	plane.rotation = tilt
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20., .10, 20.)
	shape.shape = box
	shape.position.y = -.05
	plane.add_child(shape)
	root.add_child(plane)
	return plane
