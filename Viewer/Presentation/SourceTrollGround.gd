# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceArmedLizardContact.gd"

func _process_modification_with_delta(delta: float) -> void:
	if not enabled or (not use_local_planes and plane.is_empty()):
		super._process_modification_with_delta(delta)
		return
	errors.clear()
	stance_gaps.clear()
	# Raising the entire foot preserves the source ankle angle. Downward
	# ankle rotation can swing the opposite edge of this broad sole under it.
	for index in feet.size():
		var hit: Dictionary = contacts.get(index, {}) if use_local_planes else plane
		if hit.is_empty():
			continue
		var foot: Dictionary = feet[index]
		var sole := sample_sole(foot, hit)
		if sole.is_empty() or sole.gap > .02:
			continue
		for attempt in 4:
			if sole.gap >= SoleClearance - .001:
				break
			lift_foot(foot, (SoleClearance - float(sole.gap)) / float(sole.normal.y))
			var revised := sample_sole(foot, hit)
			if revised.is_empty():
				break
			sole = revised
		stance_gaps.append(sole.gap)
		errors.append(absf(sole.gap))
	if use_local_planes and support_appendages.is_valid():
		support_appendages.call()
