extends "res://../scripts/test-pig-reaper-harpy-landings.gd"

const Preview := preload("res://../scripts/test-zombie-corpser-gargoyle-actions.gd")

func run() -> void:
	Registry.load_index()
	for body: int in Preview.ACTIONS:
		Registry.entries[body] = Preview.trial_row(body)
	for tilt: Vector3 in [Vector3.ZERO, Vector3(0.14, 0.0, 0.11), Vector3(-0.12, 0.0, -0.10)]:
		await witness(3, tilt, false)
		await witness(8, tilt, false)
		await witness(4, tilt, false)
		await witness(4, tilt, true)
		await witness(4, tilt, true, true)
	print("ZOMBIE, CORPSER AND GARGOYLE HANDOFF: 15 decoded death and removal cases, six explicit air collapses, 861 poses")
	quit()

func sample_collapse(visual: Node3D, ground: StaticBody3D, clip: String) -> void:
	var player: AnimationPlayer = visual.animator
	var rig: Skeleton3D = visual.skeleton
	var plane: Dictionary = visual.collapse_plane
	var anchor := visual.global_transform
	assert(plane.collider == ground)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.play(clip, 0.0)
	player.advance(0.0)
	for frame in 41:
		player.seek(player.current_animation_length * frame / 40.0, true)
		var gap := Ground.minimum_plane_gap(visual.collapse_skin, rig, rig.global_transform, plane.position, plane.normal)
		assert(is_finite(gap) and gap > -0.001 and visual.global_transform == anchor)
		if frame == 0 and clip == "AirDeath":
			print("GARGOYLE ", ground.rotation, " airborne wing clearance ", gap)
			assert(gap > 0.12)
		if frame == 40:
			assert(absf(gap - (0.003 if visual.native_body == 4 else 0.002)) < 0.001)
