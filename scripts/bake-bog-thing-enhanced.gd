# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/rotting-corpse-bog-thing/"
const Clips := {4: "BogThingMawSnap", 23: "BogThingSprout", 25: "BogThingQuietMaw",
	26: "BogThingMawTaste", 27: "BogThingRaisedBranches", 28: "BogThingAlertBend"}
const Lengths := {4: .72, 23: 1.25, 25: 1.12, 26: .94, 27: 1.16, 28: .89}
const Drivers := ["body", "upper jaw bone", "lower jaw bone", "r upper arm", "l upper arm",
	"r forearm", "l forearm", "r forearm b", "r ear branch", "l ear branch", "tail 01", "tail 02"]
const Samples := 90
const InitialSproutScale := .036


func run() -> void:
	var row := Registry.entry(780)
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		assert(rig.get_bone_count() == 116)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		for group: int in Clips:
			assert(library.add_animation(Clips[group], fit_affine(player.get_animation("Idle"), rig, group)) == OK)
		verify_base_clips(player, source)
		player.stop()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Destination + "780-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("BOG THING ENHANCED ", treatment, ": six fitted motions on the original affine factors")
	quit()


func fit_affine(seed: Animation, rig: Skeleton3D, group: int) -> Animation:
	var motion := Animation.new()
	motion.length = Lengths[group]
	var labels := {}
	for name: String in Drivers:
		var bone := rig.find_bone(name)
		assert(bone > 0)
		var factor := rig.get_bone_name(rig.get_bone_parent(bone))
		assert(factor.begins_with("__matrix_factor_"))
		labels[factor] = name
	var poses: Array[Dictionary] = []
	for frame in Samples + 1:
		poses.append(pose_for(group, float(frame) / Samples))
	var retained := {}
	var has_root_scale := false
	for source in seed.get_track_count():
		var kind := seed.track_get_type(source)
		var path := seed.track_get_path(source)
		var track := motion.add_track(kind)
		motion.track_set_path(track, path)
		var factor := path.get_concatenated_subnames()
		var label: String = labels.get(factor, "")
		if kind == Animation.TYPE_ROTATION_3D and not label.is_empty():
			retained[label] = true
		if kind == Animation.TYPE_SCALE_3D and factor == "__root":
			has_root_scale = true
		for frame in Samples + 1:
			var phase := float(frame) / Samples
			var time := phase * motion.length
			match kind:
				Animation.TYPE_POSITION_3D:
					motion.position_track_insert_key(track, time, seed.position_track_interpolate(source, 0.0))
				Animation.TYPE_SCALE_3D:
					var scale := seed.scale_track_interpolate(source, 0.0)
					if group == 23 and factor == "__root":
						scale *= lerpf(InitialSproutScale, 1.0, smoothstep(.04, .87, phase))
					motion.scale_track_insert_key(track, time, scale)
				Animation.TYPE_ROTATION_3D:
					var rotation := seed.rotation_track_interpolate(source, 0.0)
					var angle: Vector2 = poses[frame].get(label, Vector2.ZERO)
					rotation *= Quaternion(Vector3.RIGHT, angle.x) * Quaternion(Vector3.UP, angle.y)
					motion.rotation_track_insert_key(track, time, rotation)
				_:
					assert(false, "Unexpected source affine track")
	assert(retained.size() == Drivers.size())
	if not has_root_scale:
		var root := rig.find_bone("__root")
		var track := motion.add_track(Animation.TYPE_SCALE_3D)
		var rig_path := seed.track_get_path(0).get_concatenated_names()
		motion.track_set_path(track, NodePath("%s:__root" % rig_path))
		var neutral := rig.get_bone_pose_scale(root)
		if group == 23:
			for frame in Samples + 1:
				var phase := float(frame) / Samples
				var reveal := lerpf(InitialSproutScale, 1.0, smoothstep(.04, .87, phase))
				motion.scale_track_insert_key(track, phase * motion.length, neutral * reveal)
		else:
			motion.scale_track_insert_key(track, 0.0, neutral)
	return motion


func pose_for(group: int, phase: float) -> Dictionary:
	var mouth := 0.0
	var splay := 0.0
	var pitch := 0.0
	var sway := 0.0
	var tail := 0.0
	match group:
		4:
			mouth = pulse(phase, .06, .68, .75, .98)
			splay = .46 * mouth
			pitch = -.13 * mouth
		23:
			var rise := smoothstep(.10, .77, phase)
			pitch = .88 * (1.0 - rise)
			splay = .83 * pulse(phase, .30, .66, .72, .99)
			mouth = .35 * splay
			tail = -.23 * (1.0 - rise)
		25:
			mouth = .07 * sin(TAU * phase)
			tail = .06 * sin(TAU * phase)
		26:
			mouth = .65 * pulse(phase, .31, .51, .68, .92)
			pitch = .20 * pulse(phase, .04, .20, .29, .47)
			sway = -.23 * sin(TAU * phase)
		27:
			splay = 1.0 - .68 * smoothstep(.21, .94, phase)
			mouth = .82 * (1.0 - smoothstep(.31, .96, phase))
			sway = .30 * sin(TAU * phase)
			tail = .32 * pulse(phase, .05, .46, .51, .96)
		28:
			splay = .81 * smoothstep(.07, .51, phase)
			mouth = .40 * splay
			tail = .26 * sin(TAU * phase)
	var upper := .44 if group == 4 else .24
	var lower := -.34 if group == 4 else -.58
	return {
		"body": Vector2(pitch, .18 * sway),
		"upper jaw bone": Vector2(upper * mouth, 0), "lower jaw bone": Vector2(lower * mouth, 0),
		"r upper arm": Vector2(-.49 * splay, -.34 * splay + .21 * sway),
		"l upper arm": Vector2(-.44 * splay, .38 * splay + .12 * sway),
		"r forearm": Vector2(-.17 * splay, -.20 * splay), "l forearm": Vector2(-.19 * splay, .21 * splay),
		"r forearm b": Vector2(0, .15 * mouth if group == 4 else 0.0),
		"r ear branch": Vector2(-.19 * splay + .23 * sway, .13 * splay),
		"l ear branch": Vector2(-.27 * splay - .19 * sway, -.18 * splay),
		"tail 01": Vector2(-.24 * tail, .38 * tail), "tail 02": Vector2(-.18 * tail, .54 * tail),
	}


func pulse(phase: float, start: float, rise: float, fall: float, finish: float) -> float:
	return smoothstep(start, rise, phase) * (1.0 - smoothstep(fall, finish, phase))
