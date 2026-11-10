# SPDX-License-Identifier: GPL-3.0-or-later
extends "check-grizzle-changeling-clearance.gd"

const Assets := preload("bake-bomber-lord-enhanced.gd")
const Bomber := preload("res://Presentation/SourceEnhancedOrcBomberVisual.gd")
const Lord := preload("res://Presentation/SourceEnhancedOgreLordVisual.gd")
const Torso := ["bip01 pelvis", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 spine3",
	"bip01 neck", "bip01 head"]


func run() -> void:
	var report := {}
	for body: int in [182, 83]:
		var rows := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var path := Assets.Destination + "%d-%s.scn" % [body, treatment]
			var row := preload("res://Presentation/CreatureRegistry.gd").entry(body).duplicate(true)
			row.assets[treatment] = path
			row.assets.original = Assets.Destination + "%d-original.scn" % body
			row.archive_grounded_gestures = (Assets.Bomber if body == 182 else Assets.Lord).values()
			var actor: Node3D = Bomber.new() if body == 182 else Lord.new()
			actor.entry = row
			actor.treatment = treatment
			root.add_child(actor)
			actor.apply_identity(body, 0)
			actor.set_process(false)
			actor.set_physics_process(false)
			actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			var mesh := actor.model.find_child("Body", true, false) as MeshInstance3D
			var surface := PosedSurface.new(mesh, actor.skeleton)
			var triangles := core_triangles(surface, actor.skeleton, Torso)
			assert(not triangles.is_empty())
			var clips := {}
			for clip: String in row.archive_grounded_gestures:
				clips[clip] = check_clip(actor, surface, triangles, body == 83, clip)
				print("ORC BOMBER AND OGRE LORD GEOMETRY ", body, "/", treatment, "/", clip, " ", clips[clip])
			rows[treatment] = {"scene_sha256": FileAccess.get_sha256(path), "core_triangles": triangles.size(), "clips": clips}
			actor.free()
		report[str(body)] = rows
	var receipt := FileAccess.open(Assets.Destination + "dense-clearance-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"sample_rate": Rate, "bodies": report}, "\t"))
	receipt.close()
	quit()


func check_clip(actor: Node3D, surface: RefCounted, triangles: PackedInt32Array, armed: bool, clip: String) -> Dictionary:
	var player: AnimationPlayer = actor.animator
	var rig: Skeleton3D = actor.skeleton
	player.stop()
	actor.current_clip = clip
	player.play(clip, 0.0)
	player.advance(0.0)
	var intervals := ceili(player.current_animation_length * Rate)
	var crossing_count := 0
	var club_crossings := 0
	var first := -1.0
	var club_floor := INF
	var palm_error := 0.0
	var arms := []
	for side: String in ["l", "r"]:
		arms.append([rig.find_bone("bip01 %s forearm" % side), rig.find_bone("bip01 %s hand" % side)])
	var club_vertices := PackedVector3Array()
	if armed:
		club_vertices = actor.club.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for sample in intervals + 1:
		var phase := float(sample) / intervals
		player.seek(player.current_animation_length * phase, true)
		rig.force_update_all_bone_transforms()
		surface.update_pose()
		var crossing := false
		for arm: Array in arms:
			crossing = crosses(surface, triangles, joint_position(rig, arm[0]), joint_position(rig, arm[1])) or crossing
		if crossing:
			crossing_count += 1
		if not armed:
			continue
		assert(actor.club.visible)
		var grip: Vector3 = actor.club.global_position
		palm_error = maxf(palm_error, grip.distance_to(joint_position(rig, actor.right_grasp)))
		for point: Vector3 in club_vertices:
			club_floor = minf(club_floor, actor.club.to_global(point).y)
		var through := false
		for step in 8:
			var angle := step * TAU / 8.0
			var x := cos(angle)
			var z := sin(angle)
			var start: Vector3 = actor.club.to_global(Vector3(x * .045, -.19, z * .042))
			var end: Vector3 = actor.club.to_global(Vector3(x * .105, .69, z * .075))
			through = crosses(surface, triangles, start, end) or through
		if through:
			club_crossings += 1
			if first < 0.0:
				first = phase
	return {"samples": intervals + 1, "forearm_crossings": crossing_count, "club_crossings": club_crossings,
		"first_club_crossing": first, "club_floor": club_floor if armed else 0.0, "palm_error": palm_error}

