# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Geometry := preload("res://Presentation/SkinGeometry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Renderer := preload("res://Presentation/SourceEnhancedCrystalElementalVisual.gd")
const Fit := preload("bake-crystal-elemental-enhanced.gd")
const Rate := 240


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var base := Registry.entry(Fit.Body)
	var report := {}
	for treatment: String in base.assets:
		var row := base.duplicate(true)
		for name: String in row.assets:
			row.assets[name] = Fit.Destination + "%d-%s.scn" % [Fit.Body, name]
		row.archive_grounded_gestures = Fit.Clips.values()
		var actor := Renderer.new()
		actor.entry = row
		actor.treatment = treatment
		root.add_child(actor)
		actor.apply_identity(Fit.Body, 0x8035)
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var samples := 0
		var split_samples := 0
		var gap := INF
		for clip: String in Fit.Clips.values():
			var measured := sample_clip(actor, clip)
			samples += measured.samples
			split_samples += measured.split_samples
			gap = minf(gap, measured.gap)
		var seam := check_join(actor)
		var source_indices: int = actor.body_mesh.mesh.surface_get_array_index_len(0)
		var shard_indices := 0
		for shard: MeshInstance3D in actor.fragments.get_children():
			shard_indices += shard.mesh.surface_get_array_len(0)
		assert(shard_indices == source_indices)
		report[treatment] = {"scene_sha256": FileAccess.get_sha256(row.assets[treatment]), "samples": samples,
			"split_samples": split_samples, "gap": gap, "join_error": seam, "source_triangles": source_indices / 3}
		print("CRYSTAL SHARD CLEARANCE ", treatment, " ", report[treatment])
		actor.free()
	var file := FileAccess.open(Fit.Destination + "dense-shard-receipt.json", FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"sample_rate": Rate, "treatments": report}, "\t"))
	file.close()
	quit()


func sample_clip(actor: Node3D, clip: String) -> Dictionary:
	var player: AnimationPlayer = actor.animator
	player.stop()
	actor.current_clip = clip
	player.play(clip, 0.0)
	player.advance(0.0)
	var intervals := ceili(player.current_animation_length * Rate)
	var gap := INF
	var split_count := 0
	for sample in intervals + 1:
		var phase := float(sample) / intervals
		player.seek(player.current_animation_length * phase, true)
		actor.skeleton.force_update_all_bone_transforms()
		var split: bool = clip == actor.Assembly and phase < Fit.CrystalJoin
		assert(actor.fragments.visible == split and actor.body_mesh.visible != split)
		var clearance: float
		if split:
			split_count += 1
			clearance = actor.fragment_gap(Vector3.ZERO, Vector3.UP)
		else:
			clearance = Ground.minimum_plane_gap(actor.fitted_fall.skin, actor.skeleton,
				actor.skeleton.global_transform, Vector3.ZERO, Vector3.UP)
		assert(is_finite(clearance) and clearance > .0025)
		gap = minf(gap, clearance)
	return {"samples": intervals + 1, "split_samples": split_count, "gap": gap}


func check_join(actor: Node3D) -> float:
	var player: AnimationPlayer = actor.animator
	player.stop()
	actor.current_clip = actor.Assembly
	player.play(actor.Assembly, 0.0)
	player.advance(0.0)
	player.seek(player.current_animation_length * (Fit.CrystalJoin - .00005), true)
	var fragments := AABB()
	for part: MeshInstance3D in actor.fragments.get_children():
		var part_bounds: AABB = part.global_transform * part.mesh.get_aabb()
		fragments = fragments.merge(part_bounds) if fragments.has_volume() else part_bounds
	player.seek(player.current_animation_length * (Fit.CrystalJoin + .00005), true)
	actor.skeleton.force_update_all_bone_transforms()
	var body := Geometry.deformed_bounds(actor.body_mesh, actor.skeleton)
	var error := maxf(fragments.position.distance_to(body.position), fragments.end.distance_to(body.end))
	assert(error < .008, "A source-mesh edge jumps %.5f m as the crystals join." % error)
	return error
