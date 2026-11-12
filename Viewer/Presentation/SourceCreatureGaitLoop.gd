# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted


static func close_gaits(player: AnimationPlayer) -> void:
	for name: String in ["Walk", "Run"]:
		var motion := player.get_animation(name)
		var edge := minf(.14, motion.length * .22)
		for track in motion.get_track_count():
			close_track(motion, track, edge)


static func close_track(motion: Animation, track: int, edge: float) -> void:
	var type := motion.track_get_type(track)
	if type not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
		return
	var keys := motion.track_get_key_count(track)
	if keys < 2:
		return
	var first: Variant = sample(motion, track, type, 0.0)
	var last: Variant = sample(motion, track, type, motion.length - .00001)
	if first.is_equal_approx(last):
		return
	var seam: Variant = interpolate(first, last, type, .5)
	var replacement: Array[Array] = []
	for index in 9:
		var weight := index / 8.0
		var opening := edge * weight
		var closing := motion.length - edge * weight
		var mix := smoothstep(0.0, 1.0, weight)
		replacement.append([opening, interpolate(seam, sample(motion, track, type, opening), type, mix)])
		replacement.append([closing, interpolate(seam, sample(motion, track, type, minf(closing, motion.length - .00001)), type, mix)])
	for index in range(keys - 1, -1, -1):
		var time := motion.track_get_key_time(track, index)
		if time <= edge or time >= motion.length - edge:
			motion.track_remove_key(track, index)
	for key: Array in replacement:
		motion.track_insert_key(track, key[0], key[1])


static func sample(motion: Animation, track: int, type: Animation.TrackType, time: float) -> Variant:
	match type:
		Animation.TYPE_ROTATION_3D:
			return motion.rotation_track_interpolate(track, time)
		Animation.TYPE_SCALE_3D:
			return motion.scale_track_interpolate(track, time)
		_:
			return motion.position_track_interpolate(track, time)


static func interpolate(from: Variant, to: Variant, type: Animation.TrackType, weight: float) -> Variant:
	return from.slerp(to, weight).normalized() if type == Animation.TYPE_ROTATION_3D else from.lerp(to, weight)
