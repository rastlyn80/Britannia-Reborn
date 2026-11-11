# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/test-cyclops-titan-enhanced.gd"

const Wisp := preload("bake-shadow-wisp-enhanced.gd")
const Renderer := "res://Presentation/SourceEnhancedShadowWispVisual.gd"


func run() -> void:
	var row := Registry.entry(Wisp.Body).duplicate(true)
	row.assets.modern = Wisp.Destination + "165-modern.scn"
	var actor := load(Renderer).new() as Node3D
	actor.entry = row
	root.add_child(actor)
	actor.apply_identity(Wisp.Body, 0x901)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.position = Vector3(.55, 0, .38)
	actor.animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var skins := body_skins(actor)
	var clips: Array = ["Idle"] + Wisp.Clips.values()
	var report := {"poses": 0, "minimum_gap": INF, "maximum_anchor_drift": 0.0,
		"scene_sha256": FileAccess.get_sha256(row.assets.modern)}
	for tilt: Vector3 in Slopes:
		var floor := await create_floor(tilt)
		for clip: String in clips:
			actor.current_clip = clip
			actor.animator.play(clip, 0.0)
			actor.animator.advance(0.0)
			for sample in 31:
				seek(actor, sample / 30.0)
				actor._physics_process(0.0)
				var gap := minimum_gap(actor, floor, skins)
				assert(gap >= .020, "%s clearance %.5f metres on %s" % [clip, gap, tilt])
				report.minimum_gap = minf(report.minimum_gap, gap)
				var drift := actor.global_position.distance_to(Vector3(.55, 0, .38))
				report.maximum_anchor_drift = maxf(report.maximum_anchor_drift, drift)
				report.poses += 1
		floor.free()
		await physics_frame
	assert(report.poses == 620 and report.maximum_anchor_drift < .000001)
	actor.free()
	var receipt := FileAccess.open(Wisp.Destination + "terrain-receipt.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify(report, "\t"))
	receipt.close()
	print("SHADOW WISP TERRAIN ", report)
	quit()
