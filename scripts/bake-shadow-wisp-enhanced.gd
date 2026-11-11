# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-wisp-distinct-actions.gd"

const Body := 165
const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/shadow-wisp-enhanced/"
const Clips := {4: "ShadowWispArc", 10: "ShadowWispRecoil", 23: "ShadowWispKindle"}
const Duration := {4: .96, 10: .65, 23: .88}
const Registry := preload("res://Presentation/CreatureRegistry.gd")


func run() -> void:
	var entry := Registry.entry(Body)
	var source: String = Registry.asset_path(entry, "modern")
	assert(source == SOURCE)
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var base_clips := library.get_animation_list()
	for group: int in Clips:
		assert(library.add_animation(Clips[group], fitted(group)) == OK)
	assert(base_clips.size() + Clips.size() == library.get_animation_list().size())
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK)
	var path := Destination + "165-modern.scn"
	assert(ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS) == OK)
	print("SHADOW WISP ENHANCED: retained ", base_clips.size(), " clips, added ", Clips.values(),
		", scene ", FileAccess.get_sha256(path))
	model.free()
	quit()


func fitted(group: int) -> Animation:
	var clip := Animation.new()
	clip.length = Duration[group]
	var centre := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(centre, NodePath("Rig:EnergyRoot"))
	var turn := clip.add_track(Animation.TYPE_ROTATION_3D)
	clip.track_set_path(turn, NodePath("Rig:EnergyRoot"))
	var body_scale := add_scale_track(clip, "EnergyRoot")
	var rays: Array[int] = []
	for ray in 6:
		rays.append(add_scale_track(clip, "Ray%d" % ray))
	for frame in 121:
		var phase := float(frame) / 120.0
		var time := phase * clip.length
		var position := Vector3(0, .95, 0)
		var angle := 0.0
		var scale := Vector3.ONE
		var energy := sin(PI * phase) ** 2.0
		if group == 4:
			position.y += .04 * energy
			angle = .22 * sin(TAU * phase) * energy
			scale = Vector3(1.0 + .08 * energy, 1.0 - .08 * energy, 1.0 + .08 * energy)
		elif group == 10:
			var impact := smoothstep(.08, .29, phase) * (1.0 - smoothstep(.46, .91, phase))
			position.z -= .29 * impact
			position.y += .12 * impact
			angle = -.35 * impact
			scale = Vector3(1.0 - .22 * impact, 1.0 + .11 * impact, 1.0 - .31 * impact)
		else:
			var growth := .075 + .925 * smoothstep(.04, .79, phase)
			scale = Vector3.ONE * growth
			angle = .48 * energy
		clip.position_track_insert_key(centre, time, position)
		clip.rotation_track_insert_key(turn, time, Quaternion(Vector3.RIGHT, angle))
		clip.scale_track_insert_key(body_scale, time, scale)
		for ray in rays.size():
			var offset := float(ray) * TAU / 6.0
			var ripple := cos(TAU * phase * 1.5 - offset)
			var stretch := 1.0 + (.38 if group == 10 else .23) * ripple * energy
			if group == 23:
				stretch *= .32 + .68 * smoothstep(.31, .88, phase)
			clip.scale_track_insert_key(rays[ray], time, Vector3(1.0, stretch, 1.0))
	return clip
