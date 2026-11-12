# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceSkeletonGround.gd"


func _process_modification_with_delta(delta: float) -> void:
	# The fitted gestures have authored stances. Support the full skin
	# without stretching their feet to normal locomotion targets.
	if not visual.current_clip in visual.entry.get("archive_grounded_gestures", []) and not visual.growth.active:
		super._process_modification_with_delta(delta)


func body_lift(include_hidden: bool) -> float:
	var actual := super.body_lift(include_hidden)
	if visual.current_clip != "SnowElementalPackRise" or not use_local_planes:
		return actual
	# Hold the tread under the actor throughout the growth. The expanding
	# silhouette still clears the higher tread if its limbs reach across.
	use_local_planes = false
	var anchored := super.body_lift(include_hidden)
	use_local_planes = true
	return maxf(actual, anchored)
