# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceZombieGraveFall.gd"


func begin_emergence(actor: Node3D, source: Node3D) -> float:
	split = source.terrain.split
	if split:
		remember_floor(source, source.terrain.plane)
		initial_depth = maxf(0.0, .002 - step_gap(source.skeleton))
	var duration := begin_from_source(actor, source, source.terrain, false, not split)
	blend_length = minf(.48, duration)
	settle(actor)
	return duration
